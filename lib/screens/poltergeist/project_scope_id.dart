import 'package:flutter/widgets.dart';

import '../project/project_root.dart';

/// The open project's id, as every panel in the room asks for it.
String projectIdOf(BuildContext context) => ProjectScope.of(context);
