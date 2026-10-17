# Real-World Test Set (Tập Kiểm Thử Thực Tế)

## 1. Nguyên Tắc Vàng (Golden Rules)
1. **TUYỆT ĐỐI KHÔNG DÙNG ĐỂ HUẤN LUYỆN:** Tập ảnh này là "đề thi tốt nghiệp" độc lập cho toàn bộ các phiên bản Model (V1, V2, V3, ...). Bất kỳ ảnh nào nằm trong thư mục này sẽ **không bao giờ** được đưa vào tập train.
2. **Nguồn gốc ảnh:** Chụp thực tế từ điện thoại (Xiaomi / Android / iPhone) tại Việt Nam (sân vườn, công viên, chậu cây, vườn ươm).
3. **Mục tiêu số lượng:** 100 – 200 ảnh ban đầu (khoảng 10 – 20 ảnh / class).
4. **Gán nhãn chuẩn con người (Human Ground Truth):** Được gán nhãn thủ công cẩn thận, không dùng AI tự sinh nhãn.

## 2. Cấu Trúc 12 Thư Mục Phân Loại
```text
dataset/real_world_test/
├── Acacia/           # Cây keo / tràm
├── Bamboo-shoots/    # Măng tre / bụi tre
├── Banana-plant/     # Cây chuối
├── Banyan-Tree/      # Cây đa
├── Coconut-tree/     # Cây dừa
├── Mango-Tree/       # Cây xoài
├── Neem-Tree/        # Cây sầu đâu / neem
├── Palm-tree/        # Cây cọ
├── Papaya-Tree/      # Cây đu đủ
├── Pine/             # Cây thông
├── lemon tree/       # Cây chanh
└── peepal tree/      # Cây bồ đề
```

## 3. Tiêu Chí Đa Dạng
- **Khoảng cách:** Cận cảnh lá/cành (0.3m – 0.8m), trung cảnh (1m – 2m), toàn cây (3m+).
- **Ánh sáng:** Đầy đủ nắng, trời râm, ngược sáng, trong bóng râm, trong nhà.
- **Bộ phận:** Lá, chùm lá, thân, hoa, quả non, quả chín.
