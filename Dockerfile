FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/python:3.12-slim

# 设置apt国内源
RUN echo "deb https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 安装必要的工具
RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/*

# 复制脚本和可执行文件到固定位置，避免被挂载卷覆盖
RUN mkdir -p /opt/dify-plugin-repackaging
COPY plugin_repackaging.sh /opt/dify-plugin-repackaging/
COPY dify-plugin-* /opt/dify-plugin-repackaging/
RUN chmod +x /opt/dify-plugin-repackaging/plugin_repackaging.sh
RUN chmod +x /opt/dify-plugin-repackaging/dify-plugin-*

# 创建包装脚本，在 /app 目录执行
# 包装脚本会在 /app 中创建符号链接，让原始脚本能找到可执行文件
RUN echo '#!/bin/bash\nset -e\ncd /app\n# 创建符号链接指向可执行文件（如果不存在）\nfor f in /opt/dify-plugin-repackaging/dify-plugin-*; do\n  bn=$(basename "$f")\n  if [ ! -e "$bn" ]; then\n    ln -sf "$f" "$bn"\n  fi\ndone\n# 修改脚本内容，将 CURR_DIR 设置为 /app，并删除 Windows 行尾符\n# 使用 sed 修改脚本，tr 删除 \\r，保存到临时文件，然后执行\nTMP_SCRIPT=$(mktemp)\nsed "s|CURR_DIR=\\`dirname \\$0\\`|CURR_DIR=/app|" /opt/dify-plugin-repackaging/plugin_repackaging.sh | sed "s|cd \\$CURR_DIR|cd /app|" | tr -d "\\r" > "$TMP_SCRIPT"\nchmod +x "$TMP_SCRIPT"\nexec "$TMP_SCRIPT" "$@"' > /usr/local/bin/plugin_repackaging.sh && \
    chmod +x /usr/local/bin/plugin_repackaging.sh

# 设置工作目录为挂载点（用于输出文件）
WORKDIR /app

# 设置默认命令
CMD ["/usr/local/bin/plugin_repackaging.sh", "-p", "manylinux_2_17_x86_64", "market", "langgenius", "deepseek", "0.0.9"] 