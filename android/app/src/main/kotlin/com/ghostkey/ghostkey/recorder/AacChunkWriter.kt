package com.ghostkey.ghostkey.recorder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * One continuous AAC-LC encoder whose output is cut into `.m4a` files.
 *
 * This is where the chunk seam is closed. The PCM stream from the microphone
 * is fed to ONE MediaCodec for the whole session; the encoder never stops or
 * restarts. Its output is a sequence of access units (AUs), each exactly 1024
 * samples of audio, and every AAC-LC AU is a sync sample (there is no
 * inter-frame prediction), so the stream can be split between two MP4 files at
 * ANY AU boundary without re-encoding and without losing a sample: AU n is the
 * last sample of chunk k, AU n+1 the first of chunk k+1.
 *
 * A cut is asked for at a PCM position (`cutAt`, in samples fed so far). It is
 * honoured on the first AU whose index covers that position — so the boundary
 * lands within one AU (64 ms at 16 kHz) of where it was asked for, and always
 * AFTER the audio that was asked to be kept. The muxer rotation itself is a
 * file close and a file open on the capture thread, during which the mic keeps
 * filling AudioRecord's buffer; nothing is dropped.
 *
 * Accounting, for verifying the seam: [samplesIn] counts PCM samples fed,
 * [framesOut] counts AUs written across all files. Every chunk reports its
 * [Chunk.startFrame] and [Chunk.endFrame]; consecutive chunks meet exactly
 * (`chunk[k].startFrame == chunk[k-1].endFrame`), and at EOS
 * `framesOut * 1024 >= samplesIn` (the encoder pads the last frame).
 */
class AacChunkWriter(
  val sampleRate: Int,
  bitRate: Int,
  private val dir: File,
  private val sessionId: String,
  private val onChunk: (Chunk) -> Unit,
) {
  data class Chunk(val index: Int, val file: File, val startFrame: Long, val endFrame: Long) {
    val frames: Long get() = endFrame - startFrame
  }

  private val codec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
  private val info = MediaCodec.BufferInfo()
  private var outputFormat: MediaFormat? = null

  private var muxer: MediaMuxer? = null
  private var track = -1
  private var chunkIndex = 0
  private var chunkFile: File? = null
  private var chunkStartFrame = 0L

  /** PCM samples fed to the encoder so far. */
  @Volatile var samplesIn = 0L
    private set

  /** AAC access units written to files so far (each 1024 samples). */
  @Volatile var framesOut = 0L
    private set

  /** The AU index at which the next file begins, or null when no cut is pending. */
  private var pendingCutFrame: Long? = null
  private var eos = false

  init {
    val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
      setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
      setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
      setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, MAX_INPUT_BYTES)
    }
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
    dir.mkdirs()
  }

  /** The file the samples fed from now on are going to (until the next cut). */
  val currentPath: String
    get() = fileFor(chunkIndex).absolutePath

  /** Whether a requested cut has not yet been honoured. */
  val cutPending: Boolean get() = pendingCutFrame != null

  /**
   * Ask for the file to end at PCM position [atSample] (default: everything fed
   * so far). The rotation happens when the AU covering that position emerges
   * from the encoder, which needs up to ~2 more AUs of input — the caller keeps
   * feeding (silence, if the mic is paused) until [cutPending] clears.
   */
  fun cutAt(atSample: Long = samplesIn) {
    if (pendingCutFrame != null) return
    val frame = (atSample + AAC_FRAME - 1) / AAC_FRAME
    // Never ask for a boundary already behind the AUs written: that would be
    // an empty file. The next AU is the earliest honest cut.
    pendingCutFrame = maxOf(frame, framesOut + 1)
  }

  /** Feed [count] PCM samples (16-bit mono). Drains the encoder as it goes. */
  fun write(pcm: ShortArray, count: Int) {
    check(!eos) { "writer is closed" }
    var offset = 0
    while (offset < count) {
      val index = codec.dequeueInputBuffer(INPUT_WAIT_US)
      if (index < 0) {
        drain()
        continue
      }
      val buffer = codec.getInputBuffer(index) ?: continue
      buffer.clear()
      val take = minOf(count - offset, buffer.capacity() / 2)
      buffer.order(ByteOrder.nativeOrder()).asShortBuffer().put(pcm, offset, take)
      codec.queueInputBuffer(index, 0, take * 2, ptsUs(samplesIn), 0)
      samplesIn += take
      offset += take
      drain()
    }
  }

  /** Feed [count] samples of digital silence — used to flush a pending cut while paused. */
  fun writeSilence(count: Int) {
    write(ShortArray(count), count)
  }

  /**
   * End the stream: flush the encoder, finish the last file. Returns the last
   * chunk (also delivered through [onChunk]), or null when nothing was written.
   */
  fun finish(): Chunk? {
    if (eos) return null
    var last: Chunk? = null
    try {
      val index = codec.dequeueInputBuffer(EOS_WAIT_US)
      if (index >= 0) {
        codec.queueInputBuffer(index, 0, 0, ptsUs(samplesIn), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
      }
      val deadline = System.nanoTime() + EOS_DRAIN_NS
      while (!eos && System.nanoTime() < deadline) drain(waitUs = INPUT_WAIT_US)
      last = closeFile()
    } finally {
      eos = true
      runCatching { codec.stop() }
      runCatching { codec.release() }
    }
    return last
  }

  /** Release without finishing (an error path). The open file is left for the sweep. */
  fun abandon() {
    eos = true
    runCatching { muxer?.release() }
    muxer = null
    runCatching { codec.stop() }
    runCatching { codec.release() }
  }

  private fun drain(waitUs: Long = 0) {
    while (true) {
      val index = codec.dequeueOutputBuffer(info, waitUs)
      when {
        index == MediaCodec.INFO_TRY_AGAIN_LATER -> return
        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          outputFormat = codec.outputFormat
          if (muxer == null) openFile()
        }
        index >= 0 -> {
          val buffer = codec.getOutputBuffer(index)
          val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
          if (buffer != null && !isConfig && info.size > 0) writeFrame(buffer)
          codec.releaseOutputBuffer(index, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
            eos = true
            return
          }
        }
      }
    }
  }

  private fun writeFrame(buffer: ByteBuffer) {
    val cut = pendingCutFrame
    if (cut != null && framesOut >= cut) {
      pendingCutFrame = null
      closeFile()
      openFile()
    }
    if (muxer == null) openFile()
    val out = MediaCodec.BufferInfo()
    // Each file's clock starts at zero: the frame's position in ITS file, not
    // in the session. Counted, not copied from the encoder, so the timeline of
    // a file is exactly its AUs laid end to end.
    out.set(info.offset, info.size, ptsUs((framesOut - chunkStartFrame) * AAC_FRAME), info.flags)
    muxer!!.writeSampleData(track, buffer, out)
    framesOut += 1
  }

  private fun openFile() {
    val format = outputFormat ?: codec.outputFormat
    val file = fileFor(chunkIndex)
    file.delete()
    val m = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    track = m.addTrack(format)
    m.start()
    muxer = m
    chunkFile = file
    chunkStartFrame = framesOut
  }

  /** Close the open file and report it. An empty file is deleted and not reported. */
  private fun closeFile(): Chunk? {
    val m = muxer ?: return null
    val file = chunkFile ?: return null
    muxer = null
    chunkFile = null
    val frames = framesOut - chunkStartFrame
    if (frames <= 0) {
      // MediaMuxer.stop() throws on a track with no samples.
      runCatching { m.release() }
      file.delete()
      return null
    }
    runCatching { m.stop() }
    runCatching { m.release() }
    val chunk = Chunk(chunkIndex, file, chunkStartFrame, framesOut)
    chunkIndex += 1
    onChunk(chunk)
    return chunk
  }

  private fun fileFor(index: Int) = File(dir, "$sessionId-${index.toString().padStart(4, '0')}.m4a")

  private fun ptsUs(samples: Long): Long = samples * 1_000_000L / sampleRate

  companion object {
    /** Samples per AAC-LC access unit, per channel. Fixed by the codec. */
    const val AAC_FRAME = 1024L
    private const val MAX_INPUT_BYTES = 16 * 1024
    private const val INPUT_WAIT_US = 10_000L
    private const val EOS_WAIT_US = 200_000L
    private const val EOS_DRAIN_NS = 2_000_000_000L
  }
}
