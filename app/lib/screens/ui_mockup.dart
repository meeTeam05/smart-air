import 'package:flutter/material.dart';
import '../design/tokens.dart';
/// ── SAMPLE MOCKUP SCREEN ──────────────────────────────────────────────────
/// Màn hình này được thiết kế ĐỘC LẬP để bạn có thể review hướng UI mới.
/// Bạn có thể thử trỏ home của MaterialApp về `SampleUiMockup()` để xem trực tiếp.
/// Hướng thiết kế: Light, Tối giản (Minimal), Hiện đại, Rõ ràng.
class SampleUiMockup extends StatefulWidget {
  const SampleUiMockup({super.key});

  @override
  State<SampleUiMockup> createState() => _SampleUiMockupState();
}

class _SampleUiMockupState extends State<SampleUiMockup> {
  int _selectedRoom = 0;
  final List<String> _rooms = ['All Devices', 'Living Room', 'Bedroom', 'Kitchen'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nền sáng, hơi ngả xám nhạt (off-white) để tôn lên các thẻ Card trắng tinh.
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildRoomTabs(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildDeviceGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // Header lớn, hiện đại với font chữ sạch sẽ và thông báo chung.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning,',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A93A6), // Xám nhạt
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'My Home',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B), // Xám đậm gần đen (Slate)
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AtmosphereTokens.paper,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Color(0xFF1E293B)),
          )
        ],
      ),
    );
  }

  // Tabs danh mục dạng Pill rõ ràng, dễ bấm, tạo cảm giác app "cứng cáp" và xịn.
  Widget _buildRoomTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = _selectedRoom == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoom = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Text(
                _rooms[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AtmosphereTokens.paper : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Grid các thiết bị
  Widget _buildDeviceGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85, 
      physics: const BouncingScrollPhysics(),
      children: const [
        _MockupDeviceCard(
          name: 'Smart Air ED:8C',
          type: 'Air Purifier',
          isOnline: true,
          temp: '26.0',
          hum: '62.0',
          isActive: true,
        ),
        _MockupDeviceCard(
          name: 'Air Monitor V1',
          type: 'Sensor',
          isOnline: true,
          temp: '28.1',
          hum: '80.5',
          isActive: false,
        ),
        _MockupDeviceCard(
          name: 'Balcony Sensor',
          type: 'Sensor',
          isOnline: false,
          temp: null,
          hum: null,
          isActive: false,
        ),
      ],
    );
  }
}

class _MockupDeviceCard extends StatelessWidget {
  final String name;
  final String type;
  final bool isOnline;
  final bool isActive;
  final String? temp;
  final String? hum;

  const _MockupDeviceCard({
    required this.name,
    required this.type,
    required this.isOnline,
    required this.isActive,
    this.temp,
    this.hum,
  });

  @override
  Widget build(BuildContext context) {
    // Thẻ được thiết kế với bóng mờ siêu mịn (soft drop shadow) và góc bo viền mượt.
    return Container(
      decoration: BoxDecoration(
        color: AtmosphereTokens.paper,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04), // Bóng đổ mượt, sáng tạo cảm giác trôi nổi
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isActive ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.transparent, // Highlight thẻ nếu đang bật
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Icon & Online Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOnline 
                      ? const Color(0xFFEFF6FF)  // Xanh lam lợt
                      : const Color(0xFFF1F5F9), // Xám lợt
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.air_rounded, 
                    color: isOnline ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                    size: 24,
                  ),
                ),
                if (isOnline)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8, right: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981), // Xanh lá online (Emerald)
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 4),
                      ],
                    ),
                  )
                else 
                   Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Offline', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                   )
              ],
            ),
            
            // Middle: Information
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),

            // Bottom: Sensor Data Chips (Minimal Minimalist)
            if (isOnline && temp != null && hum != null)
              Row(
                children: [
                  _buildSensorData(Icons.thermostat_rounded, const Color(0xFFF59E0B), temp!),
                  const SizedBox(width: 8),
                  _buildSensorData(Icons.water_drop_rounded, const Color(0xFF3B82F6), hum!),
                ],
              )
            else if (!isOnline)
              const SizedBox(height: 24) // Placeholder 
          ],
        ),
      ),
    );
  }

  Widget _buildSensorData(IconData icon, Color color, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
