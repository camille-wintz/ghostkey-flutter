import '../client.dart';
import '../dto/gift.dart';
import '../errors.dart';

// The gift plan's routes. The first read after paying mints the code; the
// claim is an existing account taking a friend's; the check is public, asked
// before anyone has an account.

Future<GiftRead> getMyGift() async {
  final res = await apiFetch('/api/me/gift');
  return GiftRead.fromJson(res.jsonObject());
}

/// Take a friend's gift on this account. A refusal throws the [ServerError]
/// carrying the `GiftRefusal` (`gift_code_taken`, `same_network`, …).
Future<GiftRead> claimGift(String code) async {
  final res = await apiFetch('/api/me/gift/claim', method: 'POST', body: {'code': code});
  return GiftRead.fromJson(res.jsonObject());
}

/// What [code] gives, or throws the [ServerError] saying why it gives
/// nothing right now: `unknown_gift_code`, `gift_code_taken`, `gift_inactive`.
Future<GiftOffer> checkGiftCode(String code) async {
  final res = await apiFetch('/api/gift-codes/${Uri.encodeComponent(code)}', auth: false);
  return GiftOffer.fromJson(res.jsonObject());
}
