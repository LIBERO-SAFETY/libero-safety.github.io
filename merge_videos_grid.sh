#!/bin/bash
# 3×5 网格布局，15 个格子，每格循环播放同一任务的 15 个视频（随机顺序）
# 单个视频播完后切换到随机下一个，总时长 60 秒

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIDEOS_DIR="${SCRIPT_DIR}/videos"
OUT_DIR="${VIDEOS_DIR}/merged"
TEMP_DIR="${VIDEOS_DIR}/grid_tmp"
DURATION=60  # 总时长秒数

mkdir -p "$OUT_DIR"
mkdir -p "$TEMP_DIR"

# 生成 60 秒的 concat 列表（随机顺序，重复至超 60 秒）
gen_concat_list() {
    local task=$1
    local cell=$2
    local list_file="${TEMP_DIR}/${task}_cell${cell}_list.txt"
    # 收集 15 个文件路径
    local files=()
    for e in 0 1 2; do
        for t in 1 2 3 4 5; do
            files+=("${VIDEOS_DIR}/${task}_${e}_${t}.mp4")
        done
    done
    # 随机打乱
    local shuffled=($(printf '%s\n' "${files[@]}" | shuf))
    # 写 concat 文件，重复 3 轮确保超过 60 秒
    : > "$list_file"
    for _ in 1 2 3; do
        for f in "${shuffled[@]}"; do
            echo "file '${f}'" >> "$list_file"
        done
    done
    echo "$list_file"
}

for TASK in affordance fshoa hri tsa; do
  echo "=== 处理任务: $TASK (3×5 网格, 60秒) ==="
  CELL_FILES=()

  # 为 15 个格子各自生成 60 秒视频（随机顺序循环）
  for CELL in {0..14}; do
    LIST_FILE=$(gen_concat_list "$TASK" "$CELL")
    CELL_OUT="${TEMP_DIR}/${TASK}_cell${CELL}.mp4"
    echo "  格子 $CELL: 生成随机循环 60s..."
    ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -t $DURATION \
      -vf "scale=224:224" -c:v libx264 -preset fast -crf 23 -an "$CELL_OUT" 2>/dev/null
    CELL_FILES+=("$CELL_OUT")
  done

  # 3×5 网格拼接：5 列 × 3 行，画布 1120×672
  echo "  拼接 3×5 网格..."
  INPUTS=()
  for f in "${CELL_FILES[@]}"; do
    INPUTS+=(-i "$f")
  done

  # layout 中的 | 必须用单引号包裹，否则会被误解析为 filter 分隔符
  FILTER="[0:v][1:v][2:v][3:v][4:v][5:v][6:v][7:v][8:v][9:v][10:v][11:v][12:v][13:v][14:v]xstack=inputs=15:layout='0_0|224_0|448_0|672_0|896_0|0_224|224_224|448_224|672_224|896_224|0_448|224_448|448_448|672_448|896_448':shortest=0[v]"
  ffmpeg -y "${INPUTS[@]}" -filter_complex "$FILTER" -map "[v]" \
    -c:v libx264 -preset medium -crf 23 -an "${OUT_DIR}/${TASK}_grid_60s.mp4"

  echo "已生成: ${OUT_DIR}/${TASK}_grid_60s.mp4"
  rm -f "${TEMP_DIR}/${TASK}"_cell*.mp4 "${TEMP_DIR}/${TASK}"_cell*_list.txt
done

rmdir "$TEMP_DIR" 2>/dev/null || true
echo ""
echo "完成。输出: ${OUT_DIR}/*_grid_60s.mp4"
