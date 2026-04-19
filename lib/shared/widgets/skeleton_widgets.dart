import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base shimmer container. All skeletons use this.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF8),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton for a single transaction row (matches _buildTxItem / _buildLndItem).
class TransactionItemSkeleton extends StatelessWidget {
  const TransactionItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8F4)),
        ),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF8),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            // Amount placeholders
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 12,
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  width: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single operator card (matches _buildOperators).
class OperatorCardSkeleton extends StatelessWidget {
  const OperatorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8F4)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 9,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full dashboard body skeleton: operators row + N transaction items.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.txCount = 4, this.scrollTopPadding});

  final int txCount;
  final double? scrollTopPadding;

  @override
  Widget build(BuildContext context) {
    final topPad = scrollTopPadding ?? (MediaQuery.of(context).padding.top + 334.0);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16, topPad, 16, MediaQuery.of(context).padding.bottom + 80),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Auto-convert card skeleton
          _autoConvertSkeleton(),
          const SizedBox(height: 20),
          // Section header skeleton
          _sectionHeaderSkeleton(),
          const SizedBox(height: 10),
          // Operators skeleton
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const OperatorCardSkeleton(),
            ),
          ),
          const SizedBox(height: 20),
          // Section header skeleton
          _sectionHeaderSkeleton(),
          const SizedBox(height: 10),
          // Transaction rows
          for (int i = 0; i < txCount; i++) const TransactionItemSkeleton(),
        ],
      ),
    );
  }

  Widget _autoConvertSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8F4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF8),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeaderSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 11,
            width: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF8),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Container(
            height: 11,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF8),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal contact avatar skeleton for the send screen.
class ContactAvatarSkeleton extends StatelessWidget {
  const ContactAvatarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEF8),
      highlightColor: const Color(0xFFF8F8FF),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFEEEEF8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF8),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
