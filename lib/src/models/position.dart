/// Represents the position of a barcode in an image.
class Position {
  Position(
    this.imageWidth,
    this.imageHeight,
    this.topLeftX,
    this.topLeftY,
    this.topRightX,
    this.topRightY,
    this.bottomLeftX,
    this.bottomLeftY,
    this.bottomRightX,
    this.bottomRightY,
  );

  int imageWidth; // width of the image
  int imageHeight; // height of the image

  int topLeftX; // x coordinate of top left corner of barcode
  int topLeftY; // y coordinate of top left corner of barcode
  int topRightX; // x coordinate of top right corner of barcode
  int topRightY; // y coordinate of top right corner of barcode
  int bottomLeftX; // x coordinate of bottom left corner of barcode
  int bottomLeftY; // y coordinate of bottom left corner of barcode
  int bottomRightX; // x coordinate of bottom right corner of barcode
  int bottomRightY; // y coordinate of bottom right corner of barcode
}
