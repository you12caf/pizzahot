String formatPrice(double price) {
  if (price % 1 == 0) {
    return "${price.toInt()} DA"; // Example: 200 DA
  } else {
    return "${price.toStringAsFixed(2)} DA"; // Example: 200.50 DA
  }
}
