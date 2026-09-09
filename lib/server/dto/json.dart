// Small readers over decoded JSON. Hand-written DTOs rather than generated
// ones (see docs/flutter-port-plan.md, "Contract"): the ~25 schemas mobile
// reads are small, and a fromJson that reads like the openapi block is easier
// to diff against it than generated code is.

typedef Json = Map<String, dynamic>;

Json asJson(dynamic value) => (value as Map).cast<String, dynamic>();

List<Json> asJsonList(dynamic value) =>
    (value as List? ?? const []).map(asJson).toList();

List<String> asStringList(dynamic value) =>
    (value as List? ?? const []).cast<String>();

String asString(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

int asInt(dynamic value, [int fallback = 0]) =>
    value is int ? value : (value is num ? value.toInt() : fallback);

double asDouble(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

bool asBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;
