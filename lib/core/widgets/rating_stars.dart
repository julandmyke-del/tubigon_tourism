import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Star rating display (read-only) and interactive input widget.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.starSize = 16,
    this.color = AppColors.warning,
    this.unfilledColor = AppColors.grey300,
    this.maxStars = 5,
  });

  final double rating;
  final double starSize;
  final Color color;
  final Color unfilledColor;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final filled = rating - index;
        IconData icon;
        if (filled >= 1) {
          icon = Icons.star_rounded;
        } else if (filled >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(
          icon,
          size: starSize,
          color: filled > 0 ? color : unfilledColor,
        );
      }),
    );
  }
}

/// Interactive star rating input widget.
class RatingInput extends StatefulWidget {
  const RatingInput({
    super.key,
    required this.onChanged,
    this.initialRating = 0,
    this.starSize = 36,
    this.color = AppColors.warning,
  });

  final ValueChanged<int> onChanged;
  final int initialRating;
  final double starSize;
  final Color color;

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _rating = starIndex);
            widget.onChanged(starIndex);
          },
          child: AnimatedScale(
            scale: _rating >= starIndex ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              _rating >= starIndex
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: widget.starSize,
              color: _rating >= starIndex ? widget.color : AppColors.grey300,
            ),
          ),
        );
      }),
    );
  }
}
