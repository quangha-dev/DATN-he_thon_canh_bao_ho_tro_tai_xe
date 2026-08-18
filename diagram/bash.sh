#!/bin/bash

# Danh sách các thư mục cần tạo
# Ký tự '/' trong tên thư mục không hợp lệ trên Linux/Unix nên đã được thay bằng '-'
directories=(
    "Biểu đồ ngữ cảnh (Context Diagram)"
    "Use Case Diagram"
    "Mô hình quan hệ dữ liệu"
    "System Diagram - Biểu đồ hệ thống"
    "Database Diagram"
    "Class Diagram"
    "Activity Diagram"
    "Sequence Diagram"
    "AI Architecture Diagram"
    "Deployment Architecture"
)

# Tạo thư mục
for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    echo "Đã tạo thư mục: $dir"
done

echo "Hoàn tất tạo thư mục!"
