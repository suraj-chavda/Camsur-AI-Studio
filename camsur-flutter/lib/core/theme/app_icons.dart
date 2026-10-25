import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Modern Phosphor icons for Camsur — regular for idle, fill for selected.
abstract final class AppIcons {
  // —— Navigation ——
  static const IconData home = PhosphorIconsRegular.houseSimple;
  static const IconData homeFill = PhosphorIconsFill.houseSimple;
  static const IconData history = PhosphorIconsRegular.clockCounterClockwise;
  static const IconData historyFill = PhosphorIconsFill.clockCounterClockwise;
  static const IconData wallet = PhosphorIconsRegular.wallet;
  static const IconData walletFill = PhosphorIconsFill.wallet;
  static const IconData profile = PhosphorIconsRegular.user;
  static const IconData profileFill = PhosphorIconsFill.user;

  // —— Capture / media ——
  static const IconData camera = PhosphorIconsRegular.camera;
  static const IconData cameraFill = PhosphorIconsFill.camera;
  static const IconData gallery = PhosphorIconsRegular.images;
  static const IconData galleryFill = PhosphorIconsFill.images;
  static const IconData photo = PhosphorIconsRegular.image;
  static const IconData photoAdd = PhosphorIconsRegular.cameraPlus;
  static const IconData photoBroken = PhosphorIconsRegular.imageBroken;

  // —— Studio / AI ——
  static const IconData sparkle = PhosphorIconsRegular.sparkle;
  static const IconData sparkleFill = PhosphorIconsFill.sparkle;
  static const IconData magic = PhosphorIconsRegular.magicWand;
  static const IconData credits = PhosphorIconsRegular.lightning;
  static const IconData creditsFill = PhosphorIconsFill.lightning;
  static const IconData tools = PhosphorIconsRegular.squaresFour;

  // —— Tools (by craft) ——
  static const IconData headshot = PhosphorIconsRegular.userFocus;
  static const IconData together = PhosphorIconsRegular.usersThree;
  static const IconData passport = PhosphorIconsRegular.identificationCard;
  static const IconData removeBg = PhosphorIconsRegular.selectionBackground;

  // —— Actions ——
  static const IconData share = PhosphorIconsRegular.export;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData remove = PhosphorIconsRegular.minus;
  static const IconData refresh = PhosphorIconsRegular.arrowsClockwise;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData searchOff = PhosphorIconsRegular.magnifyingGlassMinus;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData checkCircle = PhosphorIconsFill.checkCircle;
  static const IconData trash = PhosphorIconsRegular.trash;
  static const IconData swap = PhosphorIconsRegular.arrowsLeftRight;
  static const IconData arrowForward = PhosphorIconsRegular.arrowRight;

  // —— Auth / account ——
  static const IconData mail = PhosphorIconsRegular.envelopeSimple;
  static const IconData lock = PhosphorIconsRegular.lock;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeOff = PhosphorIconsRegular.eyeSlash;
  static const IconData logout = PhosphorIconsRegular.signOut;
  static const IconData person = PhosphorIconsRegular.user;
  static const IconData google = PhosphorIconsRegular.googleLogo;
  static const IconData apple = PhosphorIconsRegular.appleLogo;

  // —— Theme ——
  static const IconData sun = PhosphorIconsRegular.sun;
  static const IconData moon = PhosphorIconsRegular.moon;
  static const IconData themeAuto = PhosphorIconsRegular.circleHalf;

  // —— Status / empty ——
  static const IconData empty = PhosphorIconsRegular.tray;
  static const IconData offline = PhosphorIconsRegular.cloudSlash;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData info = PhosphorIconsRegular.info;

  // —— Profile / misc ——
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData language = PhosphorIconsRegular.globe;
  static const IconData help = PhosphorIconsRegular.question;
  static const IconData gift = PhosphorIconsRegular.gift;
  static const IconData receipt = PhosphorIconsRegular.receipt;
  static const IconData schedule = PhosphorIconsRegular.clock;
  static const IconData tag = PhosphorIconsRegular.tag;
  static const IconData flag = PhosphorIconsRegular.flag;
  static const IconData layers = PhosphorIconsRegular.stack;
}
