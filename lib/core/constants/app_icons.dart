import 'package:flutter/widgets.dart';

/// Every icon in the app, from one family at one weight (Phosphor Light).
/// Named for what the icon means here, so a glyph can be swapped in one place.
///
/// The font is bundled in assets/fonts rather than pulled in as a package: the
/// codepoints below are the ones published by phosphor-icons (MIT).
class AppIcons {
  static const String _family = 'PhosphorLight';

  static const IconData settings = IconData(0xe434, fontFamily: _family); // slidersHorizontal
  static const IconData sidebar = IconData(0xec24, fontFamily: _family); // sidebarSimple
  static const IconData search = IconData(0xe30c, fontFamily: _family); // magnifyingGlass
  static const IconData close = IconData(0xe4f6, fontFamily: _family); // x
  static const IconData check = IconData(0xe182, fontFamily: _family); // check
  static const IconData add = IconData(0xe3d4, fontFamily: _family); // plus
  static const IconData back = IconData(0xe058, fontFamily: _family); // arrowLeft

  static const IconData windowMinimize = IconData(0xe32a, fontFamily: _family); // minus
  static const IconData windowMaximize = IconData(0xe45e, fontFamily: _family); // square

  static const IconData chats = IconData(0xe168, fontFamily: _family); // chatCircle
  static const IconData folder = IconData(0xe25a, fontFamily: _family); // folderSimple
  static const IconData folderOpen = IconData(0xe256, fontFamily: _family); // folderOpen
  static const IconData folderOff = IconData(0xec2a, fontFamily: _family); // folderSimpleDashed
  static const IconData workspace = IconData(0xe464, fontFamily: _family); // squaresFour
  static const IconData knowledge = IconData(0xe466, fontFamily: _family); // stack

  static const IconData pin = IconData(0xe65c, fontFamily: _family); // pushPinSimple
  static const IconData pinned = IconData(0xe3e2, fontFamily: _family); // pushPin
  static const IconData export = IconData(0xe20c, fontFamily: _family); // downloadSimple
  static const IconData dragHandle = IconData(0xeae2, fontFamily: _family); // dotsSixVertical

  static const IconData file = IconData(0xe23a, fontFamily: _family); // fileText
  static const IconData pdf = IconData(0xe702, fontFamily: _family); // filePdf
  static const IconData attach = IconData(0xe39a, fontFamily: _family); // paperclip
  static const IconData mention = IconData(0xe0ac, fontFamily: _family); // at

  static const IconData code = IconData(0xe1bc, fontFamily: _family); // code
  static const IconData copy = IconData(0xe1ca, fontFamily: _family); // copy
  static const IconData canvas = IconData(0xe546, fontFamily: _family); // columns
  static const IconData terminal = IconData(0xeae8, fontFamily: _family); // terminalWindow

  static const IconData send = IconData(0xe08e, fontFamily: _family); // arrowUp
  static const IconData stop = IconData(0xe46c, fontFamily: _family); // stop
  static const IconData caretUp = IconData(0xe13c, fontFamily: _family); // caretUp
  static const IconData caretDown = IconData(0xe136, fontFamily: _family); // caretDown
  static const IconData caretRight = IconData(0xe13a, fontFamily: _family); // caretRight

  static const IconData model = IconData(0xe610, fontFamily: _family); // cpu
  static const IconData modeFast = IconData(0xe2de, fontFamily: _family); // lightning
  static const IconData modeOptimal = IconData(0xe6a2, fontFamily: _family); // sparkle
  static const IconData modeThinking = IconData(0xe74e, fontFamily: _family); // brain
  static const IconData speed = IconData(0xe628, fontFamily: _family); // gauge
  static const IconData branch = IconData(0xe278, fontFamily: _family); // gitBranch
}
