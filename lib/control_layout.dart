/// Logical window size keeps rotated phones compact and spanned Duos large.
const largeControlShortestSide = 600.0;

bool allowsOneFingerPad(double shortestSide) =>
    !shortestSide.isFinite ||
    shortestSide <= 0 ||
    shortestSide < largeControlShortestSide;
