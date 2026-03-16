enum LayoutSize { phone, tablet, desktop }

LayoutSize layoutSizeForWidth(double width) {
  if (width >= 1100) {
    return LayoutSize.desktop;
  }
  if (width >= 700) {
    return LayoutSize.tablet;
  }
  return LayoutSize.phone;
}
