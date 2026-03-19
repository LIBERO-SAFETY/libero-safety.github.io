#!/bin/bash
# 将每个任务的 15 个小视频在时间轴上水平并排拼接（无缝隙）
# 画布尺寸：3360x224 (15 * 224)
# 涉及统一 scale 到 224x224（因 tsa_0_4 为 256x256）
# 时长取最短，确保各格同时有画面

set -e
VIDEOS_DIR="$(cd "$(dirname "$0")/videos" && pwd)"
OUT_DIR="${VIDEOS_DIR}/merged"
mkdir -p "$OUT_DIR"

for TASK in affordance fshoa hri tsa; do
  echo "=== 合并任务: $TASK ==="

  # 构建输入文件和 filter
  INPUTS=()
  SCALE_FILTERS=()
  for E in 0 1 2; do
    for T in 1 2 3 4 5; do
      F="${TASK}_${E}_${T}.mp4"
      FP="${VIDEOS_DIR}/${F}"
      if [[ ! -f "$FP" ]]; then
        echo "错误: 缺少文件 $FP" >&2
        exit 1
      fi
      INPUTS+=("-i" "$FP")
      IDX=$(( (E * 5) + (T - 1) ))
      # 每个输入先 scale 到 224x224，确保尺寸一致且 tsa_0_4 等非常规尺寸被统一
      SCALE_FILTERS+=("[${IDX}:v]scale=224:224,setsar=1[s${IDX}]")
    done
  done

  # 拼接 scale 与 hstack
  SCALE_PART=$(IFS=';'; echo "${SCALE_FILTERS[*]}")
  HSTACK_INPUTS=$(echo {s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14} | tr ' ' '\n' | paste -sd' ' | sed 's/ /][/g' | sed 's/^/[/' | sed 's/$/]/')
  # 简化为直接写死
  HSTACK_REF="[s0][s1][s2][s3][s4][s5][s6][s7][s8][s9][s10][s11][s12][s13][s14]"

  FILTER="${SCALE_PART};${HSTACK_REF}hstack=inputs=15[v]"

  ffmpeg -y "${INPUTS[@]}" -filter_complex "$FILTER" -map "[v]" -c:v libx264 -preset medium -crf 23 -an "${OUT_DIR}/${TASK}_merged.mp4"

  echo "已生成: ${OUT_DIR}/${TASK}_merged.mp4"
done

echo ""
echo "全部完成。输出目录: ${OUT_DIR}"
