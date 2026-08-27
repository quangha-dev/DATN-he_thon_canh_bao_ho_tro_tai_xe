param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
[xml]$document = Get-Content -LiteralPath $resolvedInput -Raw -Encoding UTF8
$page = @($document.mxfile.diagram) | Where-Object { $_.name -eq 'Kiến trúc hệ thống' } | Select-Object -First 1

if ($null -eq $page) {
    throw 'Không tìm thấy trang "Kiến trúc hệ thống".'
}

$model = $page.mxGraphModel
$root = $model.root
@($root.mxCell) | Where-Object { $_.id -notin @('0', '1') } | ForEach-Object {
    [void]$root.RemoveChild($_)
}

function Set-XmlAttribute {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$Name,
        [AllowEmptyString()][string]$Value
    )

    $Element.SetAttribute($Name, $Value)
}

function Add-Vertex {
    param(
        [string]$Id,
        [string]$Value,
        [double]$X,
        [double]$Y,
        [double]$Width,
        [double]$Height,
        [string]$Style
    )

    $cell = $document.CreateElement('mxCell')
    Set-XmlAttribute $cell 'id' $Id
    Set-XmlAttribute $cell 'value' $Value
    Set-XmlAttribute $cell 'style' $Style
    Set-XmlAttribute $cell 'vertex' '1'
    Set-XmlAttribute $cell 'parent' '1'

    $geometry = $document.CreateElement('mxGeometry')
    Set-XmlAttribute $geometry 'x' ([string]$X)
    Set-XmlAttribute $geometry 'y' ([string]$Y)
    Set-XmlAttribute $geometry 'width' ([string]$Width)
    Set-XmlAttribute $geometry 'height' ([string]$Height)
    Set-XmlAttribute $geometry 'as' 'geometry'
    [void]$cell.AppendChild($geometry)
    [void]$root.AppendChild($cell)
    return $Id
}

$script:edgeNumber = 0
function Add-Edge {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Value,
        [double]$ExitX = 0.5,
        [double]$ExitY = 0.5,
        [double]$EntryX = 0.5,
        [double]$EntryY = 0.5,
        [string]$ExtraStyle = ''
    )

    $script:edgeNumber++
    $cell = $document.CreateElement('mxCell')
    Set-XmlAttribute $cell 'id' ('arch_edge_' + $script:edgeNumber)
    Set-XmlAttribute $cell 'value' $Value
    $style = "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;endArrow=block;endFill=1;strokeColor=#333333;strokeWidth=1.2;fontSize=10;labelBackgroundColor=#ffffff;exitX=$ExitX;exitY=$ExitY;exitDx=0;exitDy=0;entryX=$EntryX;entryY=$EntryY;entryDx=0;entryDy=0;$ExtraStyle"
    Set-XmlAttribute $cell 'style' $style
    Set-XmlAttribute $cell 'edge' '1'
    Set-XmlAttribute $cell 'parent' '1'
    Set-XmlAttribute $cell 'source' $Source
    Set-XmlAttribute $cell 'target' $Target

    $geometry = $document.CreateElement('mxGeometry')
    Set-XmlAttribute $geometry 'relative' '1'
    Set-XmlAttribute $geometry 'as' 'geometry'
    [void]$cell.AppendChild($geometry)
    [void]$root.AppendChild($cell)
}

$styleTitle = 'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=20;fontStyle=1;'
$styleCaption = 'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=15;fontStyle=2;'
$styleActor = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#b7a05a;strokeWidth=1.2;fontFamily=Arial;fontSize=14;fontStyle=1;'
$styleExternal = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#e2edf6;strokeColor=#8ca8bd;strokeWidth=1.2;fontFamily=Arial;fontSize=13;fontStyle=1;'
$styleSystem = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#d9eaf7;strokeColor=#6f91ad;strokeWidth=1.6;fontFamily=Arial;fontSize=17;fontStyle=1;'
$styleContainerBlue = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f3f8fc;strokeColor=#6f91ad;strokeWidth=1.2;align=left;verticalAlign=top;spacingTop=8;spacingLeft=10;fontFamily=Arial;fontSize=14;fontStyle=1;'
$styleContainerPurple = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f0fa;strokeColor=#9673a6;strokeWidth=1.2;align=left;verticalAlign=top;spacingTop=8;spacingLeft=10;fontFamily=Arial;fontSize=14;fontStyle=1;'
$styleContainerGreen = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f2f8f2;strokeColor=#82b366;strokeWidth=1.2;align=left;verticalAlign=top;spacingTop=8;spacingLeft=10;fontFamily=Arial;fontSize=14;fontStyle=1;'
$styleNodeBlue = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;fontFamily=Arial;fontSize=12;'
$styleNodeGreen = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;fontFamily=Arial;fontSize=12;'
$styleNodePurple = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;fontFamily=Arial;fontSize=12;'
$styleData = 'shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;fillColor=#d5e8d4;strokeColor=#82b366;fontFamily=Arial;fontSize=12;'
$styleTarget = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;dashed=1;fontFamily=Arial;fontSize=11;'
$styleVps = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f7f7f7;strokeColor=#555555;strokeWidth=1.6;align=left;verticalAlign=top;spacingTop=8;spacingLeft=10;fontFamily=Arial;fontSize=14;fontStyle=1;'

# Hình 2.8 — Biểu đồ ngữ cảnh
Add-Vertex 'ctx_title' 'HÌNH 2.8 — BIỂU ĐỒ NGỮ CẢNH CỦA SAFEFLEET' 30 5 2340 30 $styleTitle | Out-Null
Add-Vertex 'ctx_driver' 'LÁI XE' 120 55 300 70 $styleActor | Out-Null
Add-Vertex 'ctx_manager' 'QUẢN LÝ' 850 55 300 70 $styleActor | Out-Null
Add-Vertex 'ctx_map' 'DỊCH VỤ BẢN ĐỒ<br>VÀ ĐỊNH TUYẾN' 1760 55 380 70 $styleExternal | Out-Null
Add-Vertex 'ctx_system' '<b>(0) HỆ THỐNG SAFEFLEET</b><br>Quản lý đội xe, điều phối chuyến và hỗ trợ an toàn lái xe' 60 275 2280 85 $styleSystem | Out-Null
Add-Vertex 'ctx_ai' 'DỊCH VỤ AI<br>BÊN NGOÀI' 420 430 330 70 $styleExternal | Out-Null
Add-Vertex 'ctx_push' 'DỊCH VỤ<br>THÔNG BÁO ĐẨY' 1600 430 330 70 $styleExternal | Out-Null

Add-Edge 'ctx_driver' 'ctx_system' 'Thông tin xác thực' 0.25 1 0.10 0
Add-Edge 'ctx_driver' 'ctx_system' 'Xác nhận và trạng thái chuyến' 0.50 1 0.14 0
Add-Edge 'ctx_driver' 'ctx_system' 'GPS, telemetry, SOS và câu hỏi' 0.75 1 0.18 0
Add-Edge 'ctx_system' 'ctx_driver' 'Kết quả xác thực và hồ sơ' 0.03 0 0.18 1
Add-Edge 'ctx_system' 'ctx_driver' 'Thông tin chuyến và chỉ dẫn tuyến' 0.06 0 0.40 1
Add-Edge 'ctx_system' 'ctx_driver' 'Cảnh báo, thông báo và câu trả lời' 0.09 0 0.65 1

Add-Edge 'ctx_manager' 'ctx_system' 'Thông tin xác thực' 0.25 1 0.42 0
Add-Edge 'ctx_manager' 'ctx_system' 'Dữ liệu quản lý và lệnh điều phối' 0.50 1 0.46 0
Add-Edge 'ctx_manager' 'ctx_system' 'Yêu cầu xử lý sự cố, báo cáo và Agent' 0.75 1 0.50 0
Add-Edge 'ctx_system' 'ctx_manager' 'Kết quả xác thực và phân quyền' 0.28 0 0.18 1
Add-Edge 'ctx_system' 'ctx_manager' 'Dữ liệu đội xe và giám sát realtime' 0.32 0 0.42 1
Add-Edge 'ctx_system' 'ctx_manager' 'Cảnh báo, sự cố, báo cáo và kết quả Agent' 0.36 0 0.70 1

Add-Edge 'ctx_system' 'ctx_map' 'Từ khóa, tọa độ và yêu cầu tìm tuyến' 0.72 0 0.20 1
Add-Edge 'ctx_map' 'ctx_system' 'Bản đồ, địa điểm, phương án tuyến và ETA' 0.55 1 0.83 0
Add-Edge 'ctx_system' 'ctx_ai' 'Yêu cầu suy luận và ngữ cảnh đã kiểm soát' 0.22 1 0.30 0
Add-Edge 'ctx_ai' 'ctx_system' 'Kết quả suy luận' 0.72 0 0.28 1
Add-Edge 'ctx_system' 'ctx_push' 'Nội dung thông báo và mã thiết bị' 0.72 1 0.30 0
Add-Edge 'ctx_push' 'ctx_system' 'Mã thông điệp và lỗi nhà cung cấp' 0.70 0 0.78 1

Add-Vertex 'ctx_caption' 'Hình 2.8. Biểu đồ ngữ cảnh của SafeFleet' 600 510 1200 25 $styleCaption | Out-Null

# Hình 2.9 — Kiến trúc logic theo tầng
Add-Vertex 'logic_title' 'HÌNH 2.9 — KIẾN TRÚC TỔNG THỂ CỦA SAFEFLEET' 30 550 2340 30 $styleTitle | Out-Null
Add-Vertex 'logic_clients_bg' 'TẦNG NGƯỜI DÙNG VÀ ỨNG DỤNG' 40 590 400 430 $styleContainerBlue | Out-Null
Add-Vertex 'logic_backend_bg' 'TẦNG BACKEND API' 470 590 470 430 $styleContainerBlue | Out-Null
Add-Vertex 'logic_ai_bg' 'TẦNG DỊCH VỤ AI' 970 590 430 430 $styleContainerPurple | Out-Null
Add-Vertex 'logic_data_bg' 'DỮ LIỆU VÀ BẰNG CHỨNG' 1430 590 420 430 $styleContainerGreen | Out-Null
Add-Vertex 'logic_ext_bg' 'DỊCH VỤ BÊN NGOÀI' 1880 590 480 430 $styleContainerBlue | Out-Null

Add-Vertex 'logic_driver' 'Lái xe' 65 630 150 50 $styleActor | Out-Null
Add-Vertex 'logic_manager' 'Quản lý' 245 630 150 50 $styleActor | Out-Null
Add-Vertex 'logic_mobile' '<b>Flutter Driver App</b><br>Android / iOS' 65 710 150 75 $styleNodeBlue | Out-Null
Add-Vertex 'logic_web' '<b>Next.js Web</b><br>Dashboard quản lý' 245 710 150 75 $styleNodeBlue | Out-Null
Add-Vertex 'logic_local_ai' 'Drowsiness Engine<br>Risk 1–10 + cảnh báo tại chỗ' 65 825 150 80 $styleNodePurple | Out-Null
Add-Vertex 'logic_offline' 'SQLite + Sync Queue<br>Retry + idempotency' 245 825 150 80 $styleNodeGreen | Out-Null

Add-Vertex 'logic_backend' '<b>Spring Boot Modular Monolith</b><br>REST · JWT/RBAC · transaction · audit' 510 640 390 80 $styleNodeBlue | Out-Null
Add-Vertex 'logic_modules' 'Fleet · Trip · Safety · Incident<br>Flood · Notification · Document · Report' 510 760 390 85 $styleNodeBlue | Out-Null
Add-Vertex 'logic_realtime' 'STOMP WebSocket + background jobs' 510 890 390 60 $styleNodeBlue | Out-Null

Add-Vertex 'logic_ai_service' '<b>FastAPI AI Service</b>' 1010 640 350 60 $styleNodePurple | Out-Null
Add-Vertex 'logic_agent' 'Agent Orchestrator<br>Plan · Execute · Check · Replan' 1010 735 165 85 $styleNodePurple | Out-Null
Add-Vertex 'logic_tools' 'MCP Tool Registry<br>RBAC + audit metadata' 1195 735 165 85 $styleNodePurple | Out-Null
Add-Vertex 'logic_rag' 'RAG Engine<br>Hybrid search + citation' 1010 865 165 75 $styleNodePurple | Out-Null
Add-Vertex 'logic_ocr' 'OCR Pipeline<br>Tesseract + VietOCR' 1195 865 165 75 $styleNodePurple | Out-Null

Add-Vertex 'logic_postgres' '<b>PostgreSQL 17 + pgvector</b><br>Nghiệp vụ · lịch sử · audit · vector' 1470 650 340 85 $styleData | Out-Null
Add-Vertex 'logic_minio' '<b>MinIO</b><br>Ảnh, chứng từ và evidence private' 1470 785 340 80 $styleData | Out-Null
Add-Vertex 'logic_redis' 'Redis — MỤC TIÊU GIAI ĐOẠN 2<br>Cache · queue · lock · scale-out' 1470 915 340 65 $styleTarget | Out-Null

Add-Vertex 'logic_openai' 'OpenAI API' 1920 640 190 60 $styleExternal | Out-Null
Add-Vertex 'logic_fcm' 'Firebase FCM' 2130 640 190 60 $styleExternal | Out-Null
Add-Vertex 'logic_route' 'Photon · Valhalla · OSRM<br>Geocoding và routing' 1920 765 400 70 $styleExternal | Out-Null
Add-Vertex 'logic_tiles' 'Map Tile Provider' 1920 890 400 60 $styleExternal | Out-Null

Add-Edge 'logic_driver' 'logic_mobile' '' 0.5 1 0.5 0
Add-Edge 'logic_manager' 'logic_web' '' 0.5 1 0.5 0
Add-Edge 'logic_mobile' 'logic_local_ai' 'Camera / Face Mesh' 0.35 1 0.35 0
Add-Edge 'logic_mobile' 'logic_offline' 'Offline queue' 0.75 1 0.20 0
Add-Edge 'logic_mobile' 'logic_backend' 'HTTPS REST' 1 0.45 0 0.30
Add-Edge 'logic_web' 'logic_backend' 'HTTPS REST + WSS/STOMP' 1 0.60 0 0.55
Add-Edge 'logic_backend' 'logic_ai_service' 'Agent / OCR request' 1 0.35 0 0.35
Add-Edge 'logic_ai_service' 'logic_backend' 'Kết quả Agent / OCR' 0 0.70 1 0.70
Add-Edge 'logic_backend' 'logic_postgres' 'JPA / JDBC' 1 0.25 0 0.25
Add-Edge 'logic_backend' 'logic_minio' 'S3 API' 1 0.75 0 0.40
Add-Edge 'logic_rag' 'logic_postgres' 'Hybrid/vector query' 1 0.40 0 0.70
Add-Edge 'logic_agent' 'logic_openai' 'Suy luận ngôn ngữ' 1 0.20 0 0.45
Add-Edge 'logic_backend' 'logic_fcm' 'Push request' 1 0.10 0 0.55
Add-Edge 'logic_backend' 'logic_route' 'Geocoding / route' 1 0.55 0 0.45
Add-Edge 'logic_mobile' 'logic_tiles' 'Map tiles' 0.85 1 0 0.45
Add-Edge 'logic_web' 'logic_tiles' 'Map tiles' 0.95 1 0 0.75
Add-Edge 'logic_backend' 'logic_redis' 'Mục tiêu: cache / queue / lock' 1 0.90 0 0.50 'dashed=1;'
Add-Vertex 'logic_caption' 'Hình 2.9. Kiến trúc tổng thể của SafeFleet' 600 1030 1200 25 $styleCaption | Out-Null

# Hình 2.10 — Kiến trúc triển khai
Add-Vertex 'deploy_title' 'HÌNH 2.10 — KIẾN TRÚC TRIỂN KHAI CỦA SAFEFLEET' 30 1070 2340 30 $styleTitle | Out-Null
Add-Vertex 'deploy_vps_bg' 'UBUNTU VPS PRODUCTION — Docker network: safefleet' 360 1120 1460 610 $styleVps | Out-Null
Add-Vertex 'deploy_docker_bg' 'MẠNG NỘI BỘ DOCKER — không public Internet' 430 1280 1320 330 $styleContainerBlue | Out-Null

Add-Vertex 'deploy_android' 'Điện thoại Android<br>SafeFleet Driver App' 40 1190 230 80 $styleActor | Out-Null
Add-Vertex 'deploy_browser' 'Trình duyệt web<br>Quản lý SafeFleet' 40 1400 230 80 $styleActor | Out-Null
Add-Vertex 'deploy_dns' 'DNS<br>fleet.example.com' 275 1295 150 65 $styleExternal | Out-Null

Add-Vertex 'deploy_firewall' 'Firewall<br>80/443 public · SSH allowlist' 500 1160 250 65 $styleNodeBlue | Out-Null
Add-Vertex 'deploy_caddy' '<b>Caddy</b><br>TLS · HTTPS/WSS · security headers' 930 1160 320 65 $styleNodeBlue | Out-Null

Add-Vertex 'deploy_frontend' 'frontend<br>Next.js :3000' 470 1330 190 70 $styleNodeBlue | Out-Null
Add-Vertex 'deploy_backend' 'backend<br>Spring Boot :8080<br>REST + STOMP + jobs' 700 1330 230 85 $styleNodeBlue | Out-Null
Add-Vertex 'deploy_ai' 'ai-service<br>FastAPI :8000' 970 1330 200 70 $styleNodePurple | Out-Null
Add-Vertex 'deploy_postgres' 'postgres<br>PostgreSQL 17 + pgvector' 1210 1330 230 75 $styleData | Out-Null
Add-Vertex 'deploy_minio' 'minio<br>S3 API :9000' 1480 1330 200 75 $styleData | Out-Null
Add-Vertex 'deploy_valhalla' 'valhalla<br>Routing :8002' 470 1480 190 70 $styleNodeGreen | Out-Null
Add-Vertex 'deploy_redis' 'redis — MỤC TIÊU<br>:6379' 700 1480 190 70 $styleTarget | Out-Null
Add-Vertex 'deploy_observe' 'Prometheus · Grafana · Loki<br>MỤC TIÊU GIAI ĐOẠN 2' 930 1480 280 70 $styleTarget | Out-Null
Add-Vertex 'deploy_volumes' 'Docker volumes<br>postgres · minio · AI models · Valhalla · Caddy' 1250 1480 430 70 $styleNodeGreen | Out-Null
Add-Vertex 'deploy_backup' '/opt/safefleet/backups<br>pg_dump · MinIO mirror · checksum' 710 1640 450 60 $styleNodeGreen | Out-Null

Add-Vertex 'deploy_openai' 'OpenAI API' 1910 1135 190 55 $styleExternal | Out-Null
Add-Vertex 'deploy_firebase' 'Firebase Cloud Messaging' 2140 1135 220 55 $styleExternal | Out-Null
Add-Vertex 'deploy_map' 'Map tiles + Photon<br>OSRM fallback' 1910 1260 450 65 $styleExternal | Out-Null
Add-Vertex 'deploy_offsite' 'Object storage / VPS thứ hai<br>Backup mã hóa off-site — mục tiêu' 1910 1390 450 70 $styleTarget | Out-Null
Add-Vertex 'deploy_github' 'GitHub Actions' 1910 1530 190 55 $styleExternal | Out-Null
Add-Vertex 'deploy_ghcr' 'GHCR<br>Image theo Git SHA' 2140 1530 220 55 $styleExternal | Out-Null

Add-Edge 'deploy_android' 'deploy_dns' 'HTTPS REST' 1 0.50 0 0.25
Add-Edge 'deploy_browser' 'deploy_dns' 'HTTPS + WSS' 1 0.50 0 0.75
Add-Edge 'deploy_dns' 'deploy_firewall' '' 1 0.50 0 0.50
Add-Edge 'deploy_firewall' 'deploy_caddy' 'HTTPS / WSS' 1 0.50 0 0.50
Add-Edge 'deploy_caddy' 'deploy_frontend' '/' 0.20 1 0.50 0
Add-Edge 'deploy_caddy' 'deploy_backend' '/api/* · /ws-native*' 0.50 1 0.50 0
Add-Edge 'deploy_backend' 'deploy_ai' 'REST nội bộ + service token' 1 0.40 0 0.40
Add-Edge 'deploy_ai' 'deploy_backend' 'MCP tool + JWT người dùng' 0 0.75 1 0.75
Add-Edge 'deploy_backend' 'deploy_postgres' 'JDBC' 1 0.25 0 0.25
Add-Edge 'deploy_ai' 'deploy_postgres' 'RAG / pgvector' 1 0.70 0 0.70
Add-Edge 'deploy_backend' 'deploy_minio' 'S3 API' 1 0.85 0 0.30
Add-Edge 'deploy_backend' 'deploy_valhalla' 'Routing HTTP' 0.30 1 0.70 0
Add-Edge 'deploy_backend' 'deploy_firebase' 'FCM Admin SDK' 1 0.10 0 0.50
Add-Edge 'deploy_ai' 'deploy_openai' 'HTTPS' 1 0.15 0 0.50
Add-Edge 'deploy_backend' 'deploy_map' 'Geocoding / fallback' 1 0.55 0 0.50
Add-Edge 'deploy_postgres' 'deploy_volumes' 'persistent volume' 0.50 1 0.30 0
Add-Edge 'deploy_minio' 'deploy_volumes' 'persistent volume' 0.50 1 0.75 0
Add-Edge 'deploy_postgres' 'deploy_backup' 'pg_dump' 0.25 1 0.70 0
Add-Edge 'deploy_minio' 'deploy_backup' 'mc mirror' 0.25 1 0.95 0
Add-Edge 'deploy_backup' 'deploy_offsite' 'Mã hóa và sao chép' 1 0.50 0 0.50 'dashed=1;'
Add-Edge 'deploy_github' 'deploy_ghcr' 'Build + push image' 1 0.50 0 0.50
Add-Edge 'deploy_ghcr' 'deploy_vps_bg' 'Deploy theo Git SHA' 0 0.75 1 0.78
Add-Vertex 'deploy_caption' 'Hình 2.10. Kiến trúc triển khai của SafeFleet' 600 1745 1200 25 $styleCaption | Out-Null

$model.SetAttribute('pageWidth', '2400')
$model.SetAttribute('pageHeight', '1800')
$model.SetAttribute('pageScale', '1')
$model.SetAttribute('page', '1')

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory)
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $false
$settings.NewLineHandling = [System.Xml.NewLineHandling]::None
$writer = [System.Xml.XmlWriter]::Create($OutputPath, $settings)
try {
    $document.Save($writer)
}
finally {
    $writer.Dispose()
}

Write-Output "Đã cập nhật trang 'Kiến trúc hệ thống': $OutputPath"
