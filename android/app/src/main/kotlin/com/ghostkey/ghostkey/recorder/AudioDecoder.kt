package com.ghostkey.ghostkey.recorder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.BufferedOutputStream
import java.io.File
import java.nio.ByteOrder

/**
 * Decode a finished chunk file back to raw 16-bit mono PCM, for the silence
 * pass in `lib/dictation/erase_silence.dart` to read.
 *
 * The audio is decoded rather than teed off the capture thread on purpose.
 * The capture side is where the chunk seam lives — [AacChunkWriter] cuts on
 * an access-unit boundary that the PCM stream does not know about — and a
 * second copy of the audio cut at a slightly different place would be a
 * source of lost or doubled words at exactly the boundary that file exists
 * to get right. Decoding the finished file instead analyses precisely the
 * bytes that would have been uploaded, which is also what the desktop does
 * (it decodes its own recorded blob).
 *
 * Little-endian samples, which is both every device Flutter runs on and what
 * a WAV wants, so the Dart side reads the file as an `Int16List` view with
 * no per-sample work.
 *
 * Returns null for anything it cannot read — no audio track, a decoder that
 * refuses the format, a truncated file, a stall. That is a DROP on the Dart
 * side, not a pass-through: see erase_silence.dart's header.
 */
object AudioDecoder {

  data class Decoded(val file: File, val sampleRate: Int, val samples: Long)

  fun decode(input: File, output: File): Decoded? {
    if (!input.isFile || input.length() <= 0) return null
    var extractor: MediaExtractor? = null
    var codec: MediaCodec? = null
    try {
      val ex = MediaExtractor().also { extractor = it }
      ex.setDataSource(input.absolutePath)
      var track = -1
      var inputFormat: MediaFormat? = null
      for (i in 0 until ex.trackCount) {
        val f = ex.getTrackFormat(i)
        if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
          track = i
          inputFormat = f
          break
        }
      }
      val format = inputFormat ?: return null
      val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
      ex.selectTrack(track)

      val c = MediaCodec.createDecoderByType(mime).also { codec = it }
      c.configure(format, null, null, 0)
      c.start()

      var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
      var channels = runCatching { format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) }.getOrDefault(1)
      var written = 0L
      var sawInputEos = false
      val info = MediaCodec.BufferInfo()
      val deadline = System.nanoTime() + DECODE_BUDGET_NS

      BufferedOutputStream(output.outputStream(), IO_BUFFER).use { out ->
        val scratch = ByteArray(IO_BUFFER)
        while (true) {
          if (System.nanoTime() > deadline) {
            Log.w(TAG, "decode of ${input.name} did not finish in time")
            return null
          }
          if (!sawInputEos) {
            val index = c.dequeueInputBuffer(WAIT_US)
            if (index >= 0) {
              val buffer = c.getInputBuffer(index)
              val size = if (buffer == null) -1 else ex.readSampleData(buffer, 0)
              if (size < 0) {
                c.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                sawInputEos = true
              } else {
                c.queueInputBuffer(index, 0, size, ex.sampleTime, 0)
                ex.advance()
              }
            }
          }

          when (val index = c.dequeueOutputBuffer(info, WAIT_US)) {
            MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
            MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
              val f = c.outputFormat
              sampleRate = runCatching { f.getInteger(MediaFormat.KEY_SAMPLE_RATE) }.getOrDefault(sampleRate)
              channels = runCatching { f.getInteger(MediaFormat.KEY_CHANNEL_COUNT) }.getOrDefault(channels)
            }
            else -> {
              if (index >= 0) {
                val buffer = c.getOutputBuffer(index)
                if (buffer != null && info.size > 0) {
                  buffer.position(info.offset)
                  buffer.limit(info.offset + info.size)
                  written += drain(buffer.order(ByteOrder.LITTLE_ENDIAN), channels, out, scratch)
                  if (written > MAX_SAMPLES) {
                    Log.w(TAG, "decode of ${input.name} ran past the ceiling")
                    return null
                  }
                }
                c.releaseOutputBuffer(index, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
              }
            }
          }
        }
      }
      if (written <= 0) return null
      return Decoded(output, sampleRate, written)
    } catch (e: Exception) {
      Log.w(TAG, "could not decode ${input.name}", e)
      output.delete()
      return null
    } finally {
      runCatching { codec?.stop() }
      runCatching { codec?.release() }
      runCatching { extractor?.release() }
    }
  }

  /**
   * Write one decoded buffer out as mono 16-bit, averaging the channels when
   * there is more than one. The recorder captures mono, so the downmix is
   * only ever insurance against a decoder that widens.
   */
  private fun drain(
    buffer: java.nio.ByteBuffer,
    channels: Int,
    out: BufferedOutputStream,
    scratch: ByteArray,
  ): Long {
    val shorts = buffer.asShortBuffer()
    var written = 0L
    var at = 0
    if (channels <= 1) {
      while (shorts.hasRemaining()) {
        val s = shorts.get().toInt()
        scratch[at++] = (s and 0xff).toByte()
        scratch[at++] = ((s shr 8) and 0xff).toByte()
        written++
        if (at == scratch.size) {
          out.write(scratch, 0, at)
          at = 0
        }
      }
    } else {
      while (shorts.remaining() >= channels) {
        var sum = 0
        for (i in 0 until channels) sum += shorts.get().toInt()
        val s = sum / channels
        scratch[at++] = (s and 0xff).toByte()
        scratch[at++] = ((s shr 8) and 0xff).toByte()
        written++
        if (at == scratch.size) {
          out.write(scratch, 0, at)
          at = 0
        }
      }
    }
    if (at > 0) out.write(scratch, 0, at)
    return written
  }

  private const val TAG = "GhostkeyDecode"
  private const val WAIT_US = 10_000L
  private const val IO_BUFFER = 1 shl 16

  /** A stalled codec must not hold a chunk's upload for the whole session. */
  private const val DECODE_BUDGET_NS = 30_000_000_000L

  /** Twenty minutes at 48 kHz — well past the ten-minute chunk cap, and a
   *  bound on what a malformed file can make this allocate. */
  private const val MAX_SAMPLES = 20L * 60 * 48_000
}
