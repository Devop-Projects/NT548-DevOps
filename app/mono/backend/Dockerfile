# Dùng image Node.js chính thức, phiên bản LTS nhỏ gọn (alpine)
# alpine = bản Linux siêu nhẹ ~5MB thay vì ~900MB
FROM node:18-alpine

# Tạo thư mục làm việc bên trong container
WORKDIR /app

# Copy package.json TRƯỚC — tận dụng Docker cache layer
# Nếu code thay đổi nhưng package.json không đổi → bỏ qua bước npm install
# → build nhanh hơn nhiều lần
COPY package*.json ./
RUN npm install --omit=dev

# Copy toàn bộ source code vào sau
COPY src/ ./src/

# Khai báo port mà container sẽ lắng nghe
EXPOSE 3000

# Lệnh chạy khi container khởi động
CMD ["node", "src/app.js"]