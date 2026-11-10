import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/jol_theme.dart';

class JolLogo extends StatelessWidget {
  const JolLogo({
    super.key,
    this.size = 36,
    this.color,
    this.withWordmark = false,
  });

  final double size;
  final Color? color;
  final bool withWordmark;

  static const _mark = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1.06 -1.06 2.12 2.7">
  <path fill-rule="evenodd" d="M0,-1A1,1 0 0 0 -1,0C-1,.72 -.4,1.22 0,1.59C.4,1.22 1,.72 1,0A1,1 0 0 0 0,-1ZM-.133,0a.22,.22 0 1 0 -.44,0a.22,.22 0 1 0 .44,0ZM.573,0a.22,.22 0 1 0 -.44,0a.22,.22 0 1 0 .44,0Z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    final markColor = color ?? JolTokens.of(context).text;
    final mark = SvgPicture.string(
      _mark,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(markColor, BlendMode.srcIn),
      semanticsLabel: 'JOL location pin logo',
    );

    if (!withWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 8),
        Text(
          'jol',
          style: Theme.of(context).textTheme.displayMedium
              ?.copyWith(fontSize: size * 0.82, color: markColor),
        ),
      ],
    );
  }
}
