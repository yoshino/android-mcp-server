FROM ruby:3.3-slim

# ビルドツール + ADB クライアントインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      android-tools-adb && \
    rm -rf /var/lib/apt/lists/*

# ホスト側ADBサーバーに接続するための環境変数
ENV ADB_SERVER_HOST=host.docker.internal

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

CMD ["bundle", "exec", "ruby", "server.rb"]
