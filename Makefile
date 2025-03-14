# ループバック用ディスクイメージと作業ディレクトリの設定
IMAGES_DIR := ./loop_images
MOUNT_DIR  := ./mnt
DISK_SIZE  := 50       # 単位: MB
N_DATA_DISK := 3       # 作成するデータディスクの数

# データディスクリストを生成 (disk1, disk2, ..., diskN)
DATA_DISK_LIST := $(shell seq -f "disk%g" 1 $(N_DATA_DISK))

# 各ディスクのイメージパスを生成
DATA_DISK_IMAGES := $(patsubst %, $(IMAGES_DIR)/%.img, $(DATA_DISK_LIST))

# 共通のパターンルール: イメージ作成とフォーマットを同時に実行
$(IMAGES_DIR)/%.img:
	@mkdir -p $(IMAGES_DIR)
	@echo "Creating $@..."
	dd if=/dev/zero of=$@ bs=1M count=$(DISK_SIZE)
	@echo "Formatting $@..."
	mkfs.ext4 -F $@

# setup ターゲット: 指定された数のディスクイメージを生成し、ワーキングディレクトリ内にマウントし、Docker コンテナを起動
setup: $(DATA_DISK_IMAGES)
	@echo "== マウントポイントの作成とマウント =="
	@mkdir -p $(patsubst %, $(MOUNT_DIR)/%, $(DATA_DISK_LIST))
	@for d in $(DATA_DISK_LIST); do \
		sudo mount -o loop $(IMAGES_DIR)/$$d.img $(MOUNT_DIR)/$$d; \
	done
	@echo "== Docker コンテナのビルド＆起動 =="
	@docker compose up --build -d
	@sleep 5  # コンテナ起動待ち
	@echo "Setup 完了。"

# test ターゲット: コンテナ内での検証実行
test:
	@echo "== コンテナ内で検証開始 =="
	@for d in $(DATA_DISK_LIST); do \
		docker compose exec snapraid bash -c "echo 'File from $$d' > /data/$$d/file.txt"; \
	done
	@echo "-- 初回 sync の実行 --"
	@docker compose exec snapraid snapraid sync
	@echo "-- 単一ファイル削除による復旧テスト（disk1） --"
	@docker compose exec snapraid bash -c "rm /data/disk1/file.txt"
	@docker compose exec snapraid snapraid fix
	@echo "検証テスト完了。"

# cleanup ターゲット: コンテナ停止と、作成したマウントポイントのアンマウント
cleanup:
	@echo "== Docker コンテナの停止 =="
	@docker compose down
	@echo "== ループバックディスクのアンマウント =="
	@for d in $(DATA_DISK_LIST); do sudo umount $(MOUNT_DIR)/$$d; done
	@echo "== ループバックデバイスの解放 =="
	@sudo losetup -D
	@echo "クリーンアップ完了。"

.PHONY: setup test cleanup
