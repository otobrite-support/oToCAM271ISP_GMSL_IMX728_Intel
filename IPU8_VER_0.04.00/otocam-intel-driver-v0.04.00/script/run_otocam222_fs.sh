#!/bin/bash
# ==============================================================================
# 腳本名稱：Intel Panther Lake (IPU7) 多路相機同步預覽與雙階段時間戳記對齊工具
# 核心機制：
#   第一階段（測試中）：純 I/O 即時將合併管線的所有原生日誌灌入實體 video_all_raw.log
#   第二階段（Ctrl+C後）：啟動 100% 純淨的 AWK 引擎執行 1ms 滑動對齊、個別日誌裁剪與總表轉換
# ==============================================================================

# 1. 宣告關聯陣列，定義底層子節點與邏輯相機名稱的一對一固定對應
declare -A CAM_MAP
CAM_MAP["otocam222 a-0"]="otocam222-1"
CAM_MAP["otocam222 b-0"]="otocam222-2"
CAM_MAP["otocam222 c-0"]="otocam222-3"
CAM_MAP["otocam222 d-0"]="otocam222-4"
CAM_MAP["otocam222 a-2"]="otocam222-5"
CAM_MAP["otocam222 b-2"]="otocam222-6"
CAM_MAP["otocam222 c-2"]="otocam222-7"
CAM_MAP["otocam222 d-2"]="otocam222-8"

# 2. 定義 Intel CameraId 與您的邏輯名稱對應表 (用於 awk 內部日誌反查)
declare -A ID_MAP
ID_MAP["0"]="otocam222-1"
ID_MAP["1"]="otocam222-2"
ID_MAP["2"]="otocam222-3"
ID_MAP["3"]="otocam222-4"
ID_MAP["4"]="otocam222-5"
ID_MAP["5"]="otocam222-6"
ID_MAP["6"]="otocam222-7"
ID_MAP["7"]="otocam222-8"

GST_CMD="gst-launch-1.0"
VALID_CAM_COUNT=0
ALIGN_LOG="video_all_cameras_alignment.txt"
AWK_FILE="align_engine.awk"
RUNNER_SH="gstreamer_runner.sh"
RAW_LOG_ALL="video_all_raw.log"

echo "======== 開始進行 Intel IPU7 硬體節點一對一精準比對 ========"

# 強制開啟 Intel 核心緩衝區 (Buffer Pool) 的 4 級偵錯日誌
export GST_DEBUG=4

# 3. 【合併指令架構】遍歷所有的 subdev 節點，動態拼接合併的 GStreamer 大指令
for name_file in /sys/class/video4linux/v4l-subdev*/name; do
    if [ -f "$name_file" ]; then
        subdev_name=$(cat "$name_file" | xargs)
        for hw_node in "${!CAM_MAP[@]}"; do
            if [[ "$subdev_name" == *"$hw_node"* ]]; then
                cam_name="${CAM_MAP[$hw_node]}"
                echo "[ OK ] 匹配成功: '$subdev_name' -> 分配 $cam_name"
                GST_CMD="$GST_CMD icamerasrc num-buffers=-1 device-name=$cam_name io-mode=mmap printfps=true ! 'video/x-raw,format=UYVY,width=1920,height=1280' ! fpsdisplaysink video-sink=glimagesink sync=false"
                ((VALID_CAM_COUNT++))
                break
            fi
        done
    fi
done

echo "========================================================"
echo "總共成功匹配並準備啟動 $VALID_CAM_COUNT 顆相機通道。"

if [ $VALID_CAM_COUNT -gt 0 ]; then
    echo "啟動 GStreamer 完整預覽中..."
    echo "第一階段：正在將合併管線日誌純文字即時儲存至 $RAW_LOG_ALL"
    echo "--------------------------------------------------------"

    # 將 BASH 的 ID_MAP 對應關係轉換為純文字字串 "0:otocam222-1,1:otocam222-2,..."
    ID_MAP_STR=""
    for id in "${!ID_MAP[@]}"; do
        if [ -n "$ID_MAP_STR" ]; then ID_MAP_STR="$ID_MAP_STR,"; fi
        ID_MAP_STR="$ID_MAP_STR${id}:${ID_MAP[$id]}"
    done

    # 將大指令直接寫入實體暫存腳本檔案，並加上 stdbuf 解快取
    echo "#!/bin/bash" > "$RUNNER_SH"
    echo "export GST_DEBUG=4" >> "$RUNNER_SH"
    echo "stdbuf -o0 -e0 $GST_CMD" >> "$RUNNER_SH"
    chmod +x "$RUNNER_SH"

    # 4. 生成 100% 純淨的獨立 awk 偵聽與 1ms 滑動對齊引擎
    # 使用 'EOF' 可以讓 $0, $4, 陣列訪問 100% 免除 Bash 轉義污染
    cat << 'EOF' > "$AWK_FILE"
    BEGIN { 
        max_seq = 0;
        cam_count = 0;
        
        # 4.1 解開傳入的相機映射關係
        split(map_data, pairs, ",");
        for (p in pairs) {
            split(pairs[p], kv, ":");
            #id_to_name[kv] = kv;
            # 【終極修正點】：kv[1] 是 CameraId (如 "0"), kv[2] 是相機名 (如 "otocam222-1")
            id_to_name[kv[1]] = kv[2];
        }
    }
    /DQ buffer done/ {
        # 4.2 提取 CameraId 
        match($0, /CameraId=[0-9]+/);
        if (RSTART > 0) {
            cam_id = substr($0, RSTART+9, RLENGTH-9);
            cam_name = id_to_name[cam_id];
        } else {
            cam_id = "unknown";
            cam_name = "unknown";
        }
        if (cam_name == "") cam_name = "unknown_cam_" cam_id;

        # 4.3 追蹤與註冊參與測試的相機
        if (!cam_seen[cam_id]) {
            cam_list[cam_count++] = cam_id;
            cam_seen[cam_id] = 1;
        }

        # 4.4 提取時間戳記 (將奈秒 ns 轉 秒 sec)
        match($0, /ts=[0-9]+/);
        if (RSTART > 0) {
            raw_ts = substr($0, RSTART+3, RLENGTH-3);
            ts = raw_ts / 1000000000.0;
        } else {
            ts = 0.0;
        }

        # 4.5 將原始數據按順序儲存在相機的歷史隊列中
        idx = raw_count[cam_id]++;
        raw_ts_array[cam_id, idx] = ts;
    }
    END {
        if (cam_count == 0) {
            print "[警告] 未能截獲任何影格日誌，無法生成對齊總表。";
            exit 0;
        }

        print "   [分析中] 正在為 " cam_count " 顆相機執行 1ms 滑動視窗起點尋找點對齊...";

        # 5.1 對相機欄位進行排序 (0, 1, 2...)
        for (i = 0; i < cam_count - 1; i++) {
            for (j = i + 1; j < cam_count; j++) {
                if (cam_list[i] > cam_list[j]) {
                    tmp = cam_list[i]; cam_list[i] = cam_list[j]; cam_list[j] = tmp;
                }
            }
        }

        # 5.2 【核心演算法】：滑動視窗尋找多路 1ms 同步鎖定起點
        for (i = 0; i < cam_count; i++) { ptr[cam_list[i]] = 0; }
        found_sync = 0; loop_guard = 0;
        
        while (loop_guard < 20000) {
            loop_guard++;
            min_ts = 9999999999.0; max_ts = -1.0; min_cam = "";
            
            for (i = 0; i < cam_count; i++) {
                c = cam_list[i];
                curr_ts = raw_ts_array[c, ptr[c]];
                if (curr_ts == "" || curr_ts == 0) { break; }
                if (curr_ts < min_ts) { min_ts = curr_ts; min_cam = c; }
                if (curr_ts > max_ts) { max_ts = curr_ts; }
            }
            if (min_cam == "") { break; }
            diff = max_ts - min_ts;
            
            # 尋找滿足小於等於 1ms (0.001秒) 的影格組合
            if (diff <= 0.001) { found_sync = 1; break; }
            ptr[min_cam]++; # 推進最落後的相機
        }

        # 如果找不到 1ms 同步，則預設歸零
        if (!found_sync) {
            print "   [警告] 無法在 1ms 內找到 Fsync 鎖定點！將預設採用各自第 0 格對齊。";
            for (i = 0; i < cam_count; i++) { ptr[cam_list[i]] = 0; }
        } else {
            print "   [鎖定成功] 成功尋找到 1ms 硬體同步起點！";
            for (i = 0; i < cam_count; i++) {
                print "              -> " id_to_name[cam_list[i]] " 起始偏移量: 原第 " ptr[cam_list[i]] " 個 Frame";
            }
        }

        # 5.3 【第一輸出】：依據起點，重新裁切並生成個別相機的標準格式 .txt 檔案
        for (i = 0; i < cam_count; i++) {
            c = cam_list[i];
            c_name = id_to_name[c];
            log_file = "video_" c_name ".txt";
            printf "" > log_file; 
            
            new_seq = 0;
            for (r = ptr[c]; r < raw_count[c]; r++) {
                printf "cap dqbuf: 0 seq: %8d bytesused: %10s ts: %.6f (ts-monotonic, ts-src-eof)\n", new_seq++, bytesused, raw_ts_array[c, r] > log_file;
            }
            close(log_file);
            print "   [ OK ] 個別日誌已重構完成: " log_file;
        }

        # 5.4 【第二輸出】：依據起點，映射到橫向矩陣中
        for (i = 0; i < cam_count; i++) {
            c = cam_list[i];
            new_s = 0;
            for (r = ptr[c]; r < raw_count[c]; r++) {
                matrix[new_s, c] = raw_ts_array[c, r];
                if (new_s > max_seq) max_seq = new_s;
                new_s++;
            }
        }

        # 5.5 寫入對齊總表標頭與 Start_Fm 偏移資訊欄位
        printf "Seq      " > align_file;
        for (i = 0; i < cam_count; i++) { printf "| %-16s ", id_to_name[cam_list[i]] >> align_file; }
        printf "| Delta(Max-Min) \n" >> align_file;
        
        printf "---------" > align_file;
        for (i = 0; i < cam_count; i++) { printf "+------------------" >> align_file; }
        printf "+----------------\n" >> align_file;

        printf "Start_Fm " >> align_file;
        for (i = 0; i < cam_count; i++) { printf "| [Index %6d]   ", ptr[cam_list[i]] >> align_file; }
        printf "| (Fsync Lock Point)\n" >> align_file;

        printf "---------" >> align_file;
        for (i = 0; i < cam_count; i++) { printf "+------------------" >> align_file; }
        printf "+----------------\n" >> align_file;

        # 5.6 逐行輸出每個對齊後序號的數據與 Delta 時間差
        for (s = 0; s <= max_seq; s++) {
            has_data = 0; min_ts = 9999999999.0; max_ts = -1.0; valid_count = 0;
            line_str = sprintf("%08d ", s);

            for (i = 0; i < cam_count; i++) {
                curr_ts = matrix[s, cam_list[i]];
                if (curr_ts != "" && curr_ts > 0) {
                    has_data = 1; valid_count++;
                    line_str = line_str sprintf("| %16.6f ", curr_ts);
                    if (curr_ts < min_ts) min_ts = curr_ts;
                    if (curr_ts > max_ts) max_ts = curr_ts;
                } else {
                    line_str = line_str "|               -- ";
                }
            }

            if (has_data) {
                if (valid_count > 1) {
                    delta = max_ts - min_ts;
                    line_str = line_str sprintf("| %.6f sec (%.3f ms)\n", delta, delta * 1000);
                } else {
                    line_str = line_str "| -- (Single Cam)\n";
                }
                printf "%s", line_str >> align_file;
            }
        }
        print "";
        printf("[ OK ] 多路時間戳記對齊總表已成功生成: %s\n", align_file);
    }
EOF

    # ==============================================================================
    # 【關鍵修改點】：第一階段——不接管線給 awk。純粹把日誌以最高速灌進單一實體 raw 檔
    # ==============================================================================
    ./"$RUNNER_SH" > "$RAW_LOG_ALL" 2>&1 &
    PIPE_PID=$!

    echo "請在 $VALID_CAM_COUNT 顆相機 Preview 畫面彈出後開始測試。"
    echo "測試完畢請在此視窗按下 [Ctrl + C] 結束測試..."
    echo "=============================================================================="

    # 6. 攔截主視窗的 Ctrl+C 觸發第二階段
    trap '
        echo ""
        echo "正在安全終止合併的 GStreamer 影像串流 (釋放 Intel 硬體資源)..."
        pkill -P $PIPE_PID gst-launch-1.0 2>/dev/null || pkill -f gstreamer_runner.sh 2>/dev/null
        wait $PIPE_PID 2>/dev/null

        # ==============================================================================
        # 第二階段：影像完全終止後，正式呼叫 awk 讀取剛產出的實體 raw 檔案進行矩陣轉換
        # 【核心修正】：縮回同一行，澈底解決 Bash 對 trap 內部多行反斜線 \ 的解析錯誤
        # ==============================================================================
        echo "--------------------------------------------------------"
        echo "第二階段啟動：GStreamer 已停止。正在將 $RAW_LOG_ALL 送入 AWK 引擎分析..."
        
        if [ -f "$RAW_LOG_ALL" ] && [ -s "$RAW_LOG_ALL" ]; then
            awk -v bytesused="4915200" -v align_file="$ALIGN_LOG" -v map_data="$ID_MAP_STR" -f "$AWK_FILE" "$RAW_LOG_ALL"
        else
            echo "[錯誤] $RAW_LOG_ALL 是空的，代表 GStreamer 未能成功運作並印出日誌。"
        fi
        
        # 清除所有中間暫存檔，維持目錄整潔
        #rm -f "$AWK_FILE"
        #rm -f "$RUNNER_SH"
        #rm -f "$RAW_LOG_ALL"
        
        echo "--------------------------------------------------------"
        echo "所有獨立日誌與 Fsync 對齊總表已生成，任務圓滿完成。"
        exit 0
    ' INT

    # 保持主行程存活，等待使用者按下 Ctrl+C 中斷
    while true; do
        sleep 1
    done
    
else
    echo "[錯誤] 未能在系統中發現任何匹配的固定的 otocam222 節點，取消起動。"
    rm -f "$AWK_FILE"
    rm -f "$RUNNER_SH"
    exit 1
fi
