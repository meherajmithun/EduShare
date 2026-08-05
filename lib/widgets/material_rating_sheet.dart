import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/material_rating_model.dart';

/// Modal bottom sheet for viewing and submitting/editing per-material ratings.
class MaterialRatingSheet extends StatefulWidget {
  final MaterialModel material;
  final VoidCallback? onRatingChanged;

  const MaterialRatingSheet({
    Key? key,
    required this.material,
    this.onRatingChanged,
  }) : super(key: key);

  static Future<void> show(BuildContext context, MaterialModel material, {VoidCallback? onRatingChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialRatingSheet(
        material: material,
        onRatingChanged: onRatingChanged,
      ),
    );
  }

  @override
  State<MaterialRatingSheet> createState() => _MaterialRatingSheetState();
}

class _MaterialRatingSheetState extends State<MaterialRatingSheet> {
  final _service = FirestoreService();
  final _reviewController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<MaterialRatingModel> _ratings = [];
  MaterialRatingModel? _myRating;
  int _selectedStars = 5;
  double _avgRating = 0.0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.getMaterialRatings(widget.material.id);
      if (mounted) {
        final myRating = res['myRating'] as MaterialRatingModel?;
        setState(() {
          _ratings = res['ratings'] as List<MaterialRatingModel>;
          _myRating = myRating;
          _avgRating = res['avgRating'] as double;
          _totalRatings = res['totalRatings'] as int;
          if (myRating != null) {
            _selectedStars = myRating.stars;
            _reviewController.text = myRating.review;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_selectedStars < 1 || _selectedStars > 5) return;
    setState(() => _isSubmitting = true);

    try {
      if (_myRating != null) {
        await _service.updateMaterialRating(
          widget.material.id,
          _selectedStars,
          review: _reviewController.text.trim(),
        );
      } else {
        await _service.addMaterialRating(
          widget.material.id,
          _selectedStars,
          review: _reviewController.text.trim(),
        );
      }

      widget.onRatingChanged?.call();
      await _loadRatings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_myRating != null ? 'Rating updated!' : 'Rating submitted!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRating() async {
    if (_myRating == null) return;
    setState(() => _isSubmitting = true);

    try {
      await _service.deleteMaterialRating(widget.material.id);
      _reviewController.clear();
      _selectedStars = 5;
      widget.onRatingChanged?.call();
      await _loadRatings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating removed.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete rating: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final isStudent = currentUser?.role == 'student';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.disabledColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Material title + summary rating
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.material.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By ${widget.material.contributorName}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_avgRating',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' ($_totalRatings)',
                        style: TextStyle(
                          color: theme.disabledColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // ── Rate Form (Students only) ──
            if (isStudent) ...[
              Text(
                _myRating != null ? 'Your Rating' : 'Rate this material',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Star picker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    iconSize: 32,
                    icon: Icon(
                      starVal <= _selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _selectedStars = starVal),
                  );
                }),
              ),
              const SizedBox(height: 10),

              // Review input
              TextField(
                controller: _reviewController,
                maxLines: 2,
                maxLength: 200,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)…',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  if (_myRating != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove'),
                      onPressed: _isSubmitting ? null : _deleteRating,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(_myRating != null ? Icons.save_rounded : Icons.send_rounded, size: 16),
                      label: Text(
                        _myRating != null ? 'Update Rating' : 'Submit Rating',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isSubmitting ? null : _submitRating,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
            ],

            // ── All Reviews list ──
            Text(
              'Reviews & Ratings (${_ratings.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            else if (_ratings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No reviews yet. Be the first to rate!',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ratings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final r = _ratings[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.ratedByName.isNotEmpty ? r.ratedByName : 'Student',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: List.generate(5, (s) {
                                return Icon(
                                  s < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: 14,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (r.review.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            r.review,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
