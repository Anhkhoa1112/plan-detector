import argparse
import sys
from pathlib import Path

# Ensure UTF-8 stdout encoding for Windows console
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# Thêm root vào sys.path để import backend modules
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

from backend.schemas.retrain import RetrainRequest
from backend.services.retrain_service import retrain_service
from backend.services.ripeness_service import ripeness_service


def run_cli_retrain(epochs: int = 25, lr: float = 0.005, task_type: str = "ripeness"):
    print("=" * 65)
    print(" BẮT ĐẦU QUY TRÌNH HUẤN LUYỆN LẠI MÔ HÌNH AI (RETRAINING PIPELINE)")
    print(f" Cấu hình: Task={task_type} | Epochs={epochs} | LR={lr}")
    print("=" * 65)

    req = RetrainRequest(
        task_type=task_type,
        epochs=epochs,
        learning_rate=lr,
        augment_angles=True,
    )

    print("\n[1/3] Đang thu thập dữ liệu huấn luyện và tạo mẫu đa phổ (RGB/HSV/Lab)...")
    dataset = retrain_service.generate_synthetic_ripeness_dataset(num_samples=max(120, epochs * 10))
    print(f"      -> Tổng số mẫu thu thập: {len(dataset)} mẫu (cân bằng 50% chín / 50% chưa chín)")

    print("\n[2/3] Đang khởi động mạng Neural Network và tối ưu hóa hàm mất mát CrossEntropyLoss...")
    res = ripeness_service.train_ripeness_model(
        samples=dataset,
        epochs=epochs,
        lr=lr,
        save_model=True,
    )

    if not res.get("success"):
        print(f" [LỖI]: Huấn luyện thất bại: {res.get('error')}")
        return

    print("\n[3/3] Quá trình huấn luyện hoàn tất thành công!")
    print("-" * 65)
    print(f" - Số Epoch đã train:     {res['epochs_trained']}")
    print(f" - Hàm mất mát (Loss):    {res['final_loss']:.4f}")
    print(f" - Độ chính xác (Accuracy): {res['final_accuracy'] * 100:.2f}%")
    print(f" - Model Checkpoint:      {res['model_path']}")
    print("-" * 65)

    # In lịch sử 5 epoch cuối
    print("\nChi tiết 5 epoch cuối:")
    for h in res["history"][-5:]:
        print(f"  Epoch {h['epoch']:02d}/{epochs:02d} | Loss: {h['loss']:.4f} | Accuracy: {h['accuracy']*100:.1f}%")

    print("\n Mô hình AI mới đã sẵn sàng phục vụ dự đoán thời gian thực!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Chạy quy trình huấn luyện lại mô hình AI")
    parser.add_argument("--epochs", type=int, default=25, help="Số epochs huấn luyện")
    parser.add_argument("--lr", type=float, default=0.005, help="Learning rate")
    parser.add_argument("--task", type=str, default="ripeness", choices=["ripeness", "multi_angle", "full"])
    args = parser.parse_args()

    run_cli_retrain(epochs=args.epochs, lr=args.lr, task_type=args.task)
