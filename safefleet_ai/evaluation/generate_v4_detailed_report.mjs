import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const evaluationDir = path.join(root, "safefleet_ai", "evaluation");
const outputFile = path.join(
  root,
  "docs",
  "BAO_CAO_DANH_GIA_GOLD_DATASET_V4_AGENT_2026-08-25.md",
);

const readJson = (name) =>
  JSON.parse(fs.readFileSync(path.join(evaluationDir, name), "utf8"));

const dataset = readJson("gold_dataset_v4.json");
const versions = [
  {
    code: "V4-A",
    title: "Bản cơ sở trước sửa",
    file: "eval_v4_results_before_fixes.json",
    data: readJson("eval_v4_results_before_fixes.json"),
  },
  {
    code: "V4-B",
    title: "Bản sau sửa lần 1 (lượt chạy gián đoạn)",
    file: "eval_v4_results_after_fixes.json",
    data: readJson("eval_v4_results_after_fixes.json"),
  },
  {
    code: "V4-C",
    title: "Bản release hợp lệ",
    file: "eval_v4_results_release.json",
    data: readJson("eval_v4_results_release.json"),
  },
];

const classificationVi = {
  PASS: "Đạt",
  QUALITY_MISMATCH: "Sai chất lượng",
  TOOL_CALL_CONTRACT_MISMATCH: "Sai hợp đồng tool",
  SYSTEM_OR_TOOL_ERROR: "Lỗi hệ thống/tool",
  EVALUATOR_ERROR: "Lỗi bộ đánh giá",
};

const releaseDiagnosis = {
  "SFV4-001": [
    "Câu trả lời nhận đúng chuyến nhưng bỏ sót tiến độ, mức rủi ro và trạng thái checklist.",
    "Người lái không có đủ dữ kiện để quyết định nhận chuyến an toàn.",
    "Dùng mẫu trả lời phân công bắt buộc đủ 5 trường: mã, trạng thái, tiến độ, rủi ro, checklist.",
  ],
  "SFV4-003": [
    "Đã lấy được dữ liệu nhưng phần tổng hợp thiếu mã chuyến và trạng thái ASSIGNED.",
    "Câu trả lời khó truy vết về đúng chuyến đang được hỏi.",
    "Sinh câu trả lời từ cấu trúc dữ liệu cố định và kiểm tra đủ trường trước khi trả về.",
  ],
  "SFV4-004": [
    "Tool chi tiết chuyến đã đủ nhưng Agent tự gọi thêm prepare_navigation ngoài yêu cầu.",
    "Tăng độ trễ, giảm precision hợp đồng tool và có thể tạo hành động không được yêu cầu.",
    "Chỉ cho phép tool hành động khi có ý định điều hướng rõ ràng; kết thúc ngay sau khi đủ dữ kiện tra cứu.",
  ],
  "SFV4-005": [
    "Nội dung gần đúng nhưng dùng cách diễn đạt “chuyến 9/phiên không hoạt động” thay cho chuỗi Gold “DEMO-TRIP-009/không có phiên lái”.",
    "Tạo false negative do bộ chấm dựa nhiều vào đối sánh cụm từ.",
    "Chuẩn hóa mã chuyến trong câu trả lời và bổ sung đối sánh ngữ nghĩa/synonym cho fact scorer.",
  ],
  "SFV4-008": [
    "Agent gọi get_current_driving_session thay vì get_safety_summary.",
    "Thiếu toàn bộ số liệu an toàn: trạng thái AVAILABLE, điểm 57, cảnh báo, thời gian lái và sự cố.",
    "Ánh xạ rõ các ý định “an toàn/cảnh báo/điểm an toàn” sang get_safety_summary.",
  ],
  "SFV4-013": [
    "Tool xếp hạng đúng nhưng câu trả lời không đưa đủ ngày, tuyến và mức rủi ro.",
    "Kết quả xếp hạng không đủ căn cứ để người dùng kiểm chứng.",
    "Bắt buộc trích các trường chứng minh từ kết quả rank vào câu trả lời cuối.",
  ],
  "SFV4-014": [
    "Agent trả câu rỗng về mặt ngữ nghĩa: “Dữ liệu hiện có 0 chuyến : .”.",
    "Người dùng không biết đây là không có chuyến đang chạy hay lỗi tải dữ liệu.",
    "Thêm nhánh diễn đạt cho tập rỗng: “Hiện không có chuyến đang chạy”.",
  ],
  "SFV4-020": [
    "Agent từ chối đúng do không có phiên lái nhưng không nêu rõ thao tác PAUSE theo yêu cầu Gold.",
    "Kết luận an toàn đúng nhưng thiếu tính truy vết tới hành động được yêu cầu.",
    "Phản hồi từ chối phải nhắc lại action, điều kiện không thỏa và trạng thái hiện tại.",
  ],
  "SFV4-025": [
    "Chỉ gọi get_trip_detail, thiếu get_trip_summary nên không xác nhận đầy đủ điều kiện ACCEPT.",
    "Có nguy cơ đề xuất nhận chuyến khi thiếu bằng chứng tổng hợp/checklist.",
    "Dùng evidence gate cho ACCEPT: detail + summary phải hoàn tất trước kết luận.",
  ],
  "SFV4-026": [
    "Thiếu get_trip_summary và bỏ sót checklist/ACCEPT trong câu trả lời.",
    "Quyết định hành động không được bảo vệ bằng đủ điều kiện nghiệp vụ.",
    "Áp dụng schema bằng chứng bắt buộc và template quyết định ACCEPT.",
  ],
  "SFV4-028": [
    "open_mobile_screen đã thành công nhưng bộ kiểm tra kế hoạch coi toàn bộ registry tool là còn thiếu, khiến Agent gọi tool liên tiếp đến STEP_LIMIT.",
    "Một hành động UI đơn giản bị biến thành workflow dài, tốn tài nguyên và trả kết quả thất bại.",
    "Kết thúc ngay khi clientAction thành công; plan gate chỉ theo tool của kế hoạch hiện tại, không theo toàn registry.",
  ],
  "SFV4-030": [
    "Heuristic làm rõ hiểu sai câu “tổng hợp theo trạng thái, không giới hạn ngày” và không gọi tool.",
    "Yêu cầu đã đủ rõ vẫn bị chặn bằng câu hỏi thừa.",
    "Điều chỉnh bộ nhận diện clarification để nhận các ràng buộc phủ định/phạm vi toàn bộ.",
  ],
  "SFV4-031": [
    "Agent dùng list_all_trips và tổng hợp được dữ liệu, trong khi Gold bắt buộc ba tool liệt kê riêng.",
    "False negative của hợp đồng tool dù phương án thực thi thay thế là hợp lệ.",
    "Cho phép acceptable_tool_plans hoặc chấm theo dữ liệu đầu ra tương đương thay vì một chuỗi tool duy nhất.",
  ],
  "SFV4-032": [
    "Đủ tool nhưng Agent tính sai số chuyến HIGH và tỷ lệ, đồng thời không tách phạm vi dữ liệu.",
    "Sai số tổng hợp có thể làm đánh giá rủi ro đội xe cao hơn thực tế.",
    "Thêm phép tổng hợp tất định/calculator và chỉ cho phép số xuất hiện trong evidence đã chuẩn hóa.",
  ],
  "SFV4-033": [
    "Agent lặp rank/detail, chọn lại cùng phụ thuộc và chạm STEP_LIMIT trước khi đủ các chuyến cần so sánh.",
    "Workflow nhiều bước không hoàn tất và tiêu tốn lượt gọi model/tool.",
    "Lưu call ledger theo tên + tham số, chống lặp, quản lý danh sách ID động và tăng bước chỉ khi có tiến triển.",
  ],
  "SFV4-034": [
    "Kế hoạch chỉ lấy phân công và tóm tắt, bỏ get_current_driving_session.",
    "Kết luận nhất quán chuyến/phiên lái thiếu một nguồn bằng chứng bắt buộc.",
    "Xây evidence schema theo loại câu hỏi và không cho COMPLETE khi còn nguồn bắt buộc.",
  ],
  "SFV4-035": [
    "Agent dùng báo cáo tháng và danh sách hoàn tất nhưng thiếu list_all_trips theo Gold.",
    "Có thể là thiếu phạm vi dữ liệu hoặc false negative nếu báo cáo tháng đã chứa tổng số tương đương.",
    "Xác định rõ nguồn chuẩn; nếu tương đương thì khai báo plan thay thế, nếu không thì bắt buộc list_all_trips.",
  ],
  "SFV4-036": [
    "Chỉ lấy thông báo, thiếu báo cáo tháng để tính tỷ lệ.",
    "Không thể đối chiếu số cảnh báo với khối lượng vận hành.",
    "Evidence gate phải yêu cầu cả numerator và denominator trước khi tổng hợp tỷ lệ.",
  ],
  "SFV4-037": [
    "Chỉ lấy thông báo, thiếu get_monthly_report.",
    "Phân tích xu hướng cảnh báo không có mẫu số và bối cảnh thời gian.",
    "Ràng buộc kế hoạch phân tích cảnh báo với báo cáo kỳ tương ứng.",
  ],
  "SFV4-038": [
    "Tool normalization đổi list_upcoming_trips thành rank_upcoming_trips và Agent lặp rank ba lần.",
    "Điểm hợp đồng tool thấp dù câu trả lời có phần lớn fact đúng; tăng chi phí do gọi lặp.",
    "Không rewrite tool khi cả list và rank đều cần; thêm dedup và plan thay thế trong Gold.",
  ],
  "SFV4-039": [
    "list_all_trips đã trả nhiều trường chi tiết nhưng Gold vẫn đòi hai lần get_trip_detail.",
    "Có nguy cơ false negative; câu trả lời vẫn thiếu nhấn mạnh đây là hai chuyến khác nhau.",
    "Chấm theo độ đầy đủ evidence; chỉ bắt detail khi payload danh sách không đủ trường.",
  ],
  "SFV4-040": [
    "Vòng lặp chỉ ghi tool message cho một phần parallel tool_calls rồi gửi lại lịch sử, gây OpenAI 400.",
    "Workflow dừng hoàn toàn, không có câu trả lời nghiệp vụ.",
    "Thực thi và append phản hồi cho mọi tool_call_id trong cùng assistant turn hoặc tắt parallel_tool_calls.",
  ],
  "SFV4-041": [
    "Shortcut an toàn kết thúc sau assignment/session, bỏ qua yêu cầu audit checklist của các chuyến sắp tới.",
    "Báo cáo kiểm tra lịch không đầy đủ và không phát hiện các chuyến thiếu checklist.",
    "Chỉ dùng shortcut cho câu hỏi an toàn trực tiếp; ưu tiên evidence schema của yêu cầu audit rõ ràng.",
  ],
  "SFV4-042": [
    "Planner trôi mục tiêu, lặp rank/detail và hết bước trước safety/summary.",
    "Không hoàn thành ưu tiên đa tiêu chí trong workflow dài.",
    "Tách kế hoạch thành các slot evidence, đánh dấu slot đã hoàn tất và cấm gọi lại cùng tham số.",
  ],
  "SFV4-043": [
    "Lịch sử parallel tool_calls thiếu tool response nên API trả 400.",
    "Mất toàn bộ kết quả tổng hợp tuyến/rủi ro.",
    "Bảo toàn tính nguyên tử của một assistant tool-call turn và thêm test nhiều tool song song.",
  ],
  "SFV4-044": [
    "Lỗi 400 do thiếu phản hồi cho một tool_call_id trong batch song song.",
    "Workflow hòa giải nhiều nguồn dừng giữa chừng.",
    "Xử lý đủ batch tool trước kiểm tra step limit/early return; kiểm thử invariant lịch sử message.",
  ],
  "SFV4-045": [
    "Có assignment/session nhưng thiếu get_trip_summary.",
    "Khuyến nghị hành động và quản lý chuyến thiếu trạng thái tổng hợp/điều kiện ACCEPT.",
    "Không cho kết luận action khi slot summary chưa hoàn thành.",
  ],
  "SFV4-046": [
    "Có session/assignment nhưng thiếu get_safety_summary và các fact AVAILABLE, 57, COMPLETE.",
    "Đánh giá khả năng tiếp tục lái thiếu dữ liệu an toàn cốt lõi.",
    "Gắn mọi quyết định tiếp tục lái với safety summary bắt buộc.",
  ],
  "SFV4-047": [
    "Có detail và warehouse issue nhưng thiếu trip summary.",
    "So sánh trạng thái giao hàng và vấn đề kho không đầy đủ.",
    "Bổ sung summary vào evidence gate và template đối chiếu trạng thái.",
  ],
  "SFV4-048": [
    "Lỗi lịch sử parallel tool_calls 400 sau khi đã gọi một số tool; có thêm warehouse tool ngoài nhu cầu.",
    "Không tạo được phép tính/kết luận cuối và lãng phí tool call.",
    "Sửa batch tool-call, giới hạn tool theo kế hoạch và kiểm tra đủ evidence trước tổng hợp.",
  ],
  "SFV4-049": [
    "Các tool cần thiết đã gọi nhưng bị lặp, Agent chạm STEP_LIMIT và không phát câu trả lời cuối.",
    "Có dữ liệu nhưng người dùng vẫn nhận thông báo thất bại.",
    "Khi required-call set đã đủ thì ép finalization; dedup tên + tham số và không replan nếu không có evidence mới.",
  ],
  "SFV4-050": [
    "Safety checker coi phát hiện buồn ngủ/SOS là lỗi thực thi và dừng trước khi thu thập các nguồn còn lại.",
    "Tình huống nguy hiểm được nhận ra nhưng báo cáo tổng hợp và khuyến nghị vận hành không hoàn tất.",
    "Phân biệt “phát hiện rủi ro” với SYSTEM ERROR; tiếp tục thu thập read-only evidence rồi kết luận an toàn ưu tiên.",
  ],
};

function cell(value, limit = 260) {
  if (value === null || value === undefined || value === "") return "—";
  const text = String(value)
    .replace(/\r?\n/g, " ")
    .replace(/\|/g, "\\|")
    .replace(/\s+/g, " ")
    .trim();
  return text.length > limit ? `${text.slice(0, limit - 1)}…` : text;
}

function pct(value) {
  return `${(Number(value || 0) * 100).toFixed(0)}%`;
}

function expectedCalls(result) {
  const calls = result.toolCallContract?.missing || [];
  const fromContract = calls.map((item) => item.name).filter(Boolean);
  return fromContract.length ? fromContract : result.expectedTools || [];
}

function actualCalls(result) {
  return (result.actualTools || []).length ? result.actualTools : ["không gọi tool"];
}

function evidence(result) {
  const facts = result.diagnostics?.missingFacts || [];
  if (result.classification === "PASS") {
    return `Đủ điều kiện chấm; status=${result.actualStatus}`;
  }
  if (result.classification === "EVALUATOR_ERROR") {
    return cell(result.actualAnswer || "Kết nối backend bị đóng", 210);
  }
  if (facts.length) return `Thiếu fact: ${facts.join(", ")}`;
  const unexpected = result.toolCallContract?.unexpected?.map((x) => x.name) || [];
  if (unexpected.length) return `Tool ngoài hợp đồng: ${unexpected.join(", ")}`;
  return cell(result.actualAnswer, 210);
}

function genericDiagnosis(version, result) {
  if (result.classification === "PASS") {
    return [
      "Tool, trạng thái và fact đạt ngưỡng Gold.",
      "Không ghi nhận ảnh hưởng bất lợi trong phạm vi case.",
      "Giữ làm regression case; không nới tiêu chí chấm.",
    ];
  }
  if (result.classification === "EVALUATOR_ERROR") {
    return [
      "Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng.",
      "Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ.",
      "Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá.",
    ];
  }
  if (result.classification === "SYSTEM_OR_TOOL_ERROR") {
    const parallel400 = String(result.actualAnswer || "").includes("tool_call_id");
    return parallel400
      ? [
          "Lịch sử hội thoại thiếu tool response tương ứng một parallel tool_call_id nên API trả 400.",
          "Workflow dừng trước khi tạo kết luận nghiệp vụ.",
          "Append đủ mọi tool response trong một batch hoặc tắt parallel_tool_calls; thêm invariant test cho message history.",
        ]
      : [
          "Bộ điều phối hoặc tool checker chuyển workflow sang FAILED.",
          "Không có kết quả cuối đáng tin cậy cho người dùng.",
          "Tách lỗi hạ tầng khỏi kết quả nghiệp vụ, lưu trace và cho phép hoàn tất các truy vấn read-only an toàn.",
        ];
  }
  if (result.classification === "TOOL_CALL_CONTRACT_MISMATCH") {
    const missing = expectedCalls(result).join(", ");
    return [
      `Kế hoạch/call ledger không hoàn tất tool bắt buộc${missing ? `: ${missing}` : ""}.`,
      "Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision.",
      "Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc.",
    ];
  }
  if (version.code === "V4-A") {
    return [
      "Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08.",
      "Có thể tạo false negative; không phù hợp để làm điểm release.",
      "Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất.",
    ];
  }
  const facts = result.diagnostics?.missingFacts || [];
  return [
    `Câu trả lời thiếu/sai fact hoặc diễn đạt${facts.length ? `: ${facts.join(", ")}` : " theo ngưỡng Gold"}.`,
    "Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai.",
    "Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành.",
  ];
}

function diagnosis(version, result) {
  if (version.code === "V4-C" && releaseDiagnosis[result.id]) {
    return releaseDiagnosis[result.id];
  }
  return genericDiagnosis(version, result);
}

function versionRows(version) {
  return version.data.results
    .map((result) => {
      const goldCase = dataset.cases.find((item) => item.id === result.id) || {};
      const [cause, impact, fix] = diagnosis(version, result);
      const expected = (result.expectedTools || goldCase.expected_tools || []).join(", ") || "không cần tool";
      const actual = actualCalls(result).join(", ");
      const level = result.difficultyLevel || goldCase.difficulty_level || "?";
      const turn = result.turnIndex || goldCase.turn_index || "?";
      const status = result.actualStatus || "N/A";
      return `| ${result.id} | L${level}/T${turn} | ${classificationVi[result.classification] || result.classification} (${status}) | E: ${cell(expected, 150)}<br>A: ${cell(actual, 170)} | ${cell(evidence(result), 220)} | ${cell(cause, 250)} | ${cell(impact, 220)} | ${cell(fix, 260)} |`;
    })
    .join("\n");
}

function crossVersionRows() {
  const byVersion = versions.map((v) => new Map(v.data.results.map((r) => [r.id, r])));
  return dataset.cases
    .map((goldCase) => {
      const states = byVersion.map((map) => map.get(goldCase.id)?.classification || "MISSING");
      const release = byVersion[2].get(goldCase.id);
      const trend =
        release?.classification === "PASS"
          ? "Đạt ở release"
          : states[0] !== states[2]
            ? "Có thay đổi, vẫn chưa đạt"
            : "Chưa cải thiện phân loại";
      return `| ${goldCase.id} | L${goldCase.difficulty_level} | ${classificationVi[states[0]] || states[0]} | ${classificationVi[states[1]] || states[1]} | ${classificationVi[states[2]] || states[2]} | ${trend} |`;
    })
    .join("\n");
}

function levelRows(version) {
  return Object.entries(version.data.levels || {})
    .map(
      ([difficultyLevel, level]) =>
        `| L${difficultyLevel} | ${level.total} | ${level.passed} | ${level.total - level.passed} | ${pct(level.passRate)} |`,
    )
    .join("\n");
}

function summaryRow(version) {
  const s = version.data.summary;
  const counts = s.classificationCounts || {};
  const validity =
    version.code === "V4-A"
      ? "Không dùng làm release: snapshot cũ, chưa có fingerprint preflight"
      : version.code === "V4-B"
        ? "Không dùng làm release: 13 EVALUATOR_ERROR do backend restart"
        : "Hợp lệ: preflight khớp, đủ 50 case, không có EVALUATOR_ERROR";
  return `| ${version.code} | ${version.title} | ${s.passed}/${s.total} (${pct(s.passRate)}) | ${counts.QUALITY_MISMATCH || 0} | ${counts.TOOL_CALL_CONTRACT_MISMATCH || 0} | ${counts.SYSTEM_OR_TOOL_ERROR || 0} | ${counts.EVALUATOR_ERROR || 0} | ${s.durationSeconds}s | ${validity} |`;
}

const release = versions[2].data;
const snapshot = release.snapshotPreflight || {};
const avg = release.summary.averageScores;
const levelDesign = [
  [1, "Tra cứu trực tiếp", "1 nguồn/ý định; câu ngắn", "10"],
  [2, "Tra cứu có ngữ cảnh", "Nối tiếp hội thoại, điều kiện bổ sung", "10"],
  [3, "Hành động và kiểm soát", "Tool hành động, xác nhận, phân quyền", "10"],
  [4, "Lập luận đa nguồn", "Tổng hợp, so sánh, tỷ lệ, nhất quán", "10"],
  [5, "Workflow dài", "Nhiều nguồn, rủi ro, hành động và an toàn", "10"],
]
  .map((x) => `| ${x[0]} | ${x[1]} | ${x[2]} | ${x[3]} |`)
  .join("\n");

const report = `# BÁO CÁO CHI TIẾT GOLD DATASET V4 VÀ ĐÁNH GIÁ SAFEFLEET AGENT

**Ngày đánh giá:** 25/08/2026  
**Phạm vi:** SafeFleet AI Agent, dữ liệu thật PostgreSQL, hội thoại nhiều lượt dùng câu trả lời thực tế của Agent làm lịch sử  
**Dataset:** \`${dataset.corpus_id}\`  
**Bản release được chấp nhận:** V4-C  
**Kết luận chính:** V4-C chạy đủ 50/50 case, snapshot hợp lệ, đạt **${release.summary.passed}/${release.summary.total} (${pct(release.summary.passRate)})**. Hệ thống làm tốt nhóm trực tiếp và kiểm soát an toàn cơ bản nhưng chưa đạt yêu cầu release cho workflow dài: L4 và L5 đều 0/10.

> Quy ước: “E” là tool Gold mong đợi; “A” là tool Agent thực tế gọi. Báo cáo phân biệt lỗi Agent, lỗi hợp đồng Gold và lỗi hạ tầng evaluator để tránh quy sai nguyên nhân.

---

# PHẦN I — THIẾT KẾ DATASET VÀ SO SÁNH CÁC PHIÊN BẢN

## 1. Mục tiêu và cấu trúc Gold Dataset V4

Bộ dữ liệu có 50 câu, chia thành 10 workflow, mỗi workflow 5 lượt. Độ dài, số ràng buộc, số nguồn dữ liệu và yêu cầu lập luận tăng sau mỗi nhóm 10 câu. Lịch sử hội thoại không dùng đáp án Gold giả lập mà dùng chính câu trả lời thật của Agent ở lượt trước; vì vậy lỗi ở một lượt có thể ảnh hưởng các lượt sau giống vận hành thực tế.

| Mức | Tên mức | Đặc trưng | Số case |
|---:|---|---|---:|
${levelDesign}

Các kiểm soát tính đúng của evaluator:

- Snapshot live bất biến: \`${release.snapshotId}\`.
- Fingerprint: \`${snapshot.actualFingerprint || dataset.snapshot_fingerprint}\`.
- Preflight V4-C: \`${snapshot.matches === true ? "MATCH" : "KHÔNG XÁC ĐỊNH"}\`; số chuyến: ${snapshot.actualTripCount || dataset.snapshot?.trip_count || 11}.
- Nếu fingerprint DB khác Gold, runner phải từ chối phát hành điểm thay vì tạo false negative.
- Phân loại lỗi: PASS, QUALITY_MISMATCH, TOOL_CALL_CONTRACT_MISMATCH, SYSTEM_OR_TOOL_ERROR và EVALUATOR_ERROR.

## 2. Tóm tắt ba phiên bản

| Bản | Mô tả | Đạt | Sai chất lượng | Sai tool | Lỗi hệ thống/tool | Lỗi evaluator | Thời gian | Giá trị sử dụng |
|---|---|---:|---:|---:|---:|---:|---:|---|
${versions.map(summaryRow).join("\n")}

### 2.1. Nguyên nhân khác biệt giữa ba lượt

- **V4-A:** đạt 13/50 nhưng Gold dùng snapshot 15/08 trong khi backend đã có dữ liệu 25/08. Lượt này hữu ích để tìm lỗi nhưng không hợp lệ làm mốc release vì lỗi dữ liệu và lỗi Agent bị trộn lẫn.
- **V4-B:** các sửa đổi nâng kết quả quan sát lên 19 case đạt; tuy nhiên case 38–50 bị \`Remote end closed connection without response\` khi backend được recreate. 13 case này là EVALUATOR_ERROR, không phải lỗi nghiệp vụ của Agent, nên 38% chỉ là số chẩn đoán tạm thời.
- **V4-C:** chạy lại với snapshot/fingerprint khớp và hạ tầng ổn định. Đây là kết quả chính thức: 18/50. Điểm thấp hơn V4-B một case không phải hồi quy chắc chắn vì V4-B chưa hoàn thành hợp lệ toàn bộ tập.

## 3. Ma trận kết quả qua phiên bản

| Case | Mức | V4-A | V4-B | V4-C | Xu hướng |
|---|---:|---|---|---|---|
${crossVersionRows()}

## 4. Chi tiết từng case — V4-A (trước sửa)

**Bối cảnh bản:** snapshot \`${versions[0].data.snapshotId}\`, thời điểm tham chiếu ${versions[0].data.referenceDatetime}; chưa có fingerprint preflight. Mọi QUALITY_MISMATCH cần được đọc cùng cảnh báo drift dữ liệu.

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân | Ảnh hưởng | Cách sửa |
|---|---:|---|---|---|---|---|---|
${versionRows(versions[0])}

## 5. Chi tiết từng case — V4-B (sau sửa lần 1, bị gián đoạn)

**Bối cảnh bản:** snapshot đã đóng băng và preflight khớp. Case 38–50 không có kết quả Agent hợp lệ vì backend bị restart trong lúc chạy; không được chuyển EVALUATOR_ERROR thành thất bại Agent.

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân | Ảnh hưởng | Cách sửa |
|---|---:|---|---|---|---|---|---|
${versionRows(versions[1])}

---

# PHẦN II — BẢN RELEASE, PHÂN TÍCH TỪNG CASE VÀ KẾ HOẠCH SỬA

## 6. Kết quả release V4-C

| Mức | Tổng | Đạt | Không đạt | Tỷ lệ đạt |
|---:|---:|---:|---:|---:|
${levelRows(versions[2])}

Các chỉ số trung bình:

| Chỉ số | Điểm |
|---|---:|
| Coherence | ${avg.coherence.toFixed(4)} |
| Completeness | ${avg.completeness.toFixed(4)} |
| Correctness | ${avg.correctness.toFixed(4)} |
| Relevance | ${avg.relevance.toFixed(4)} |
| Task completion | ${avg.taskCompletion.toFixed(4)} |
| Tool-call contract F1 | ${avg.toolCallContractF1.toFixed(4)} |
| Tool-call precision | ${avg.toolCallContractPrecision.toFixed(4)} |
| Tool-call recall | ${avg.toolCallContractRecall.toFixed(4)} |

Nhận định: coherence 0,98 cho thấy câu trả lời thường có hình thức dễ đọc, nhưng correctness/completeness chỉ khoảng 0,596 và tool-contract F1 khoảng 0,712. Vì vậy vấn đề chính không nằm ở văn phong mà ở việc thu thập đủ bằng chứng, thực hiện đúng chuỗi tool và tổng hợp số liệu.

## 7. Chi tiết từng case — V4-C release

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân gốc | Ảnh hưởng | Cách sửa cụ thể |
|---|---:|---|---|---|---|---|---|
${versionRows(versions[2])}

## 8. Tổng hợp nguyên nhân gốc

| Nhóm nguyên nhân | Case tiêu biểu | Mức độ | Kết luận kỹ thuật |
|---|---|---|---|
| Thiếu evidence/tool bắt buộc | 008, 025–027, 034, 036–037, 041, 045–047, 050 | Cao | Planner có thể kết thúc khi kế hoạch tự sinh đã xong dù yêu cầu nghiệp vụ vẫn thiếu nguồn dữ liệu. |
| Lặp tool và STEP_LIMIT | 028, 033, 038, 042, 049 | Cao | Chưa có call ledger/dedup đủ mạnh; plan checker đôi khi coi tool ngoài kế hoạch là còn thiếu. |
| Lịch sử parallel tool-call không hợp lệ | 040, 043, 044, 048 | Chặn release | Assistant message chứa nhiều tool_calls nhưng vòng lặp không append đủ tool response cho mọi ID trước lượt model kế tiếp. |
| Sai/thiếu fact khi tổng hợp | 001, 003, 013, 014, 020, 032 | Cao | Finalizer chưa được ràng buộc bởi schema evidence và chưa có phép tính tất định. |
| Gold contract quá cứng hoặc scorer từ vựng | 005, 031, 035, 038, 039 | Trung bình | Một số cách gọi tool/diễn đạt tương đương bị tính sai; cần plan thay thế và scorer ngữ nghĩa có kiểm soát. |
| Clarification/shortcut sai ngữ cảnh | 030, 041, 050 | Cao | Heuristic ưu tiên nhầm, làm ngắt workflow dù yêu cầu đã rõ hoặc mới chỉ phát hiện rủi ro. |

## 9. Các sửa đổi đã hoàn thành giữa V4-A và V4-C

1. **Khóa snapshot và fingerprint:** tạo snapshot live bất biến, tính SHA-256 và từ chối chấm khi DB drift.
2. **Plan completion gate:** không cho Agent trả lời cuối khi còn tool đã cam kết trong kế hoạch.
3. **Phát hiện tool JSON giả:** nếu model in JSON tool ra nội dung thay vì phát \`tool_calls\`, orchestrator yêu cầu phát lệnh tool thật.
4. **Chẩn đoán provider:** lỗi OpenAI 400 được trả về với chi tiết đã làm sạch để xác định đúng nguyên nhân.
5. **Regression tests:** bổ sung test cho evaluator V4, orchestrator và OpenAI provider.

Các sửa này giải quyết tính lặp lại của phép đo và một phần lỗi kết thúc sớm, nhưng chưa giải quyết triệt để batch parallel tool-call, dedup và evidence schema theo nghiệp vụ.

## 10. Kế hoạch sửa tiếp theo theo ưu tiên

### P0 — Chặn lỗi hệ thống trước khi chạy release mới

1. Tắt \`parallel_tool_calls\` tạm thời hoặc thực thi nguyên tử toàn bộ batch.
2. Thêm invariant: mỗi \`tool_call_id\` trong assistant message phải có đúng một tool message trước lượt model tiếp theo.
3. Thêm test tái hiện trực tiếp case 040, 043, 044 và 048.

**Tiêu chí đạt:** không còn SYSTEM_OR_TOOL_ERROR do message history trong 50 case.

### P1 — Hoàn thiện workflow dài

1. Xây evidence schema theo intent: mỗi intent có danh sách slot dữ liệu bắt buộc và các plan thay thế được chấp nhận.
2. Lưu call ledger theo \`tool name + normalized arguments\`; cấm lặp nếu kết quả trước thành công và không có dữ kiện mới.
3. Chỉ tăng bước khi call tạo evidence mới; khi đủ required slots phải chuyển sang finalization.
4. Tách “phát hiện nguy hiểm” khỏi lỗi hệ thống: rủi ro là evidence thành công, không phải trạng thái ERROR.

**Tiêu chí đạt:** L4 tối thiểu 7/10, L5 tối thiểu 6/10; không còn STEP_LIMIT do gọi lặp.

### P2 — Nâng độ đúng của nội dung và evaluator

1. Finalizer dùng dữ liệu có cấu trúc; các tỷ lệ/số đếm do hàm tất định tính.
2. Template bắt buộc các fact quan trọng cho assignment, session, safety, action và checklist.
3. Gold hỗ trợ \`acceptable_tool_plans\` khi nhiều chuỗi tool cung cấp evidence tương đương.
4. Fact scorer chuẩn hóa mã chuyến, trạng thái và synonym nhưng vẫn cấm suy diễn số không có trong evidence.

**Tiêu chí đạt:** correctness và completeness trung bình ≥ 0,85; tool-call F1 ≥ 0,85.

## 11. Điều kiện nghiệm thu đề xuất

- Chạy tối thiểu 3 lần liên tiếp trên cùng snapshot; mỗi lần đủ 50 case và không có EVALUATOR_ERROR.
- Tỷ lệ đạt tổng ≥ 80%; không mức độ nào dưới 60%.
- Không có SYSTEM_OR_TOOL_ERROR trong case read-only.
- 100% action nhạy cảm trả đúng ALLOW/DENY/REQUIRE_CONFIRMATION và không thực hiện khi thiếu xác nhận.
- Không có số liệu/tỷ lệ ngoài evidence; không có gọi tool lặp cùng tham số sau thành công.
- Lưu kèm result JSON, snapshot ID, fingerprint, commit và thời gian chạy cho mỗi lần nghiệm thu.

## 12. Lệnh và hiện vật kiểm chứng

- Dataset: \`safefleet_ai/evaluation/gold_dataset_v4.json\`
- Snapshot: \`safefleet_ai/evaluation/gold_dataset_v4_live_snapshot.json\`
- V4-A: \`safefleet_ai/evaluation/eval_v4_results_before_fixes.json\`
- V4-B: \`safefleet_ai/evaluation/eval_v4_results_after_fixes.json\`
- V4-C: \`safefleet_ai/evaluation/eval_v4_results_release.json\`
- Validator: \`safefleet_ai/evaluation/validate_gold_dataset_v4.py\`
- Runner: \`safefleet_ai/evaluation/run_eval_v4.py\`
- Test: \`safefleet_ai/tests/test_evaluation_v4.py\`, \`test_agent.py\`, \`test_openai_provider.py\`

Kết quả kiểm thử mã ở thời điểm lập báo cáo: **21 passed, 1 warning**. Lượt V4-C hoàn thành đủ 50 case trong **${release.summary.durationSeconds} giây**, độ trễ trung bình **${release.summary.averageLatencySeconds} giây/case**.

---

**Kết luận cuối:** V4-C là phép đo hợp lệ đầu tiên của bộ Gold Dataset V4. Agent đã có nền tảng tốt ở truy vấn/hành động ngắn, nhưng chưa đủ điều kiện nghiệm thu production cho workflow đa bước. Bốn việc cần làm trước tiên là sửa batch parallel tool-call, thêm evidence schema, chống lặp tool và dùng finalizer tất định. Sau khi hoàn tất, phải chạy lại toàn bộ 50 case trên cùng snapshot thay vì suy luận điểm từ lượt V4-B bị gián đoạn.
`;

fs.writeFileSync(outputFile, report, "utf8");
console.log(outputFile);
console.log(`characters=${report.length}, lines=${report.split("\n").length}`);
