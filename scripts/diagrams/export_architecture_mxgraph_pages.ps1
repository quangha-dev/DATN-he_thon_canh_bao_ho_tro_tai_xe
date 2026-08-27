param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDrawio,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourcePath = (Resolve-Path -LiteralPath $SourceDrawio).Path
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    [void](New-Item -ItemType Directory -Path $OutputDirectory)
}
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path

[xml]$source = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
$architecturePage = @($source.mxfile.diagram) |
    Where-Object { $_.name -eq 'Kiến trúc hệ thống' } |
    Select-Object -First 1

if ($null -eq $architecturePage) {
    throw 'Không tìm thấy trang "Kiến trúc hệ thống" trong file nguồn.'
}

$sourceCells = @($architecturePage.mxGraphModel.root.mxCell)

function Set-VertexGeometry {
    param(
        [System.Xml.XmlElement]$Root,
        [string]$Id,
        [double]$X,
        [double]$Y,
        [double]$Width,
        [double]$Height
    )

    $cell = @($Root.mxCell) | Where-Object { $_.GetAttribute('id') -eq $Id } | Select-Object -First 1
    if ($null -eq $cell) {
        throw "Không tìm thấy vertex $Id."
    }
    $geometry = $cell.SelectSingleNode('./mxGeometry')
    $geometry.SetAttribute('x', [string]$X)
    $geometry.SetAttribute('y', [string]$Y)
    $geometry.SetAttribute('width', [string]$Width)
    $geometry.SetAttribute('height', [string]$Height)
}

function Set-EdgeLane {
    param(
        [System.Xml.XmlElement]$Root,
        [string]$Source,
        [string]$Target,
        [string]$OriginalValue,
        [double]$ExitX,
        [double]$ExitY,
        [double]$EntryX,
        [double]$EntryY
    )

    $edge = @($Root.mxCell) | Where-Object {
        $_.GetAttribute('edge') -eq '1' -and
        $_.GetAttribute('source') -eq $Source -and
        $_.GetAttribute('target') -eq $Target -and
        $_.GetAttribute('value') -eq $OriginalValue
    } | Select-Object -First 1
    if ($null -eq $edge) {
        throw "Không tìm thấy edge: $Source -> $Target ($OriginalValue)."
    }

    $edge.SetAttribute('value', '')
    $edge.SetAttribute('style', "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=10;html=1;endArrow=block;endFill=1;strokeColor=#202020;strokeWidth=1.5;exitX=$ExitX;exitY=$ExitY;exitDx=0;exitDy=0;entryX=$EntryX;entryY=$EntryY;entryDx=0;entryDy=0;")
    $geometry = $edge.SelectSingleNode('./mxGeometry')
    while ($geometry.HasChildNodes) {
        [void]$geometry.RemoveChild($geometry.FirstChild)
    }
}

function Add-FlowLabel {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Root,
        [string]$Id,
        [string]$Value,
        [double]$X,
        [double]$Y,
        [double]$Width,
        [double]$Height
    )

    $cell = $Document.CreateElement('mxCell')
    $cell.SetAttribute('id', $Id)
    $cell.SetAttribute('value', $Value)
    $cell.SetAttribute('style', 'text;html=1;whiteSpace=wrap;overflow=hidden;strokeColor=#ffffff;fillColor=#ffffff;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=14;spacing=4;')
    $cell.SetAttribute('vertex', '1')
    $cell.SetAttribute('parent', '1')
    $geometry = $Document.CreateElement('mxGeometry')
    $geometry.SetAttribute('x', [string]$X)
    $geometry.SetAttribute('y', [string]$Y)
    $geometry.SetAttribute('width', [string]$Width)
    $geometry.SetAttribute('height', [string]$Height)
    $geometry.SetAttribute('as', 'geometry')
    [void]$cell.AppendChild($geometry)
    [void]$Root.AppendChild($cell)
}

function Optimize-ContextDiagram {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Root
    )

    Set-VertexGeometry $Root 'ctx_title' 30 70 2340 40
    Set-VertexGeometry $Root 'ctx_driver' 160 200 420 100
    Set-VertexGeometry $Root 'ctx_manager' 900 200 420 100
    Set-VertexGeometry $Root 'ctx_map' 1760 200 460 100
    Set-VertexGeometry $Root 'ctx_system' 60 900 2280 120
    Set-VertexGeometry $Root 'ctx_ai' 430 1340 400 100
    Set-VertexGeometry $Root 'ctx_push' 1580 1340 400 100
    Set-VertexGeometry $Root 'ctx_caption' 600 1530 1200 35

    # Sáu lane riêng cho Lái xe.
    Set-EdgeLane $Root 'ctx_system' 'ctx_driver' 'Kết quả xác thực và hồ sơ' 0.061 0 0.095 1
    Set-EdgeLane $Root 'ctx_system' 'ctx_driver' 'Thông tin chuyến và chỉ dẫn tuyến' 0.101 0 0.348 1
    Set-EdgeLane $Root 'ctx_system' 'ctx_driver' 'Cảnh báo, thông báo và câu trả lời' 0.141 0 0.564 1
    Set-EdgeLane $Root 'ctx_driver' 'ctx_system' 'Thông tin xác thực' 0.650 1 0.164 0
    Set-EdgeLane $Root 'ctx_driver' 'ctx_system' 'Xác nhận và trạng thái chuyến' 0.790 1 0.190 0
    Set-EdgeLane $Root 'ctx_driver' 'ctx_system' 'GPS, telemetry, SOS và câu hỏi' 0.930 1 0.216 0

    # Sáu lane riêng cho Quản lý.
    Set-EdgeLane $Root 'ctx_system' 'ctx_manager' 'Kết quả xác thực và phân quyền' 0.382 0 0.071 1
    Set-EdgeLane $Root 'ctx_system' 'ctx_manager' 'Dữ liệu đội xe và giám sát realtime' 0.413 0 0.238 1
    Set-EdgeLane $Root 'ctx_system' 'ctx_manager' 'Cảnh báo, sự cố, báo cáo và kết quả Agent' 0.443 0 0.405 1
    Set-EdgeLane $Root 'ctx_manager' 'ctx_system' 'Thông tin xác thực' 0.595 1 0.478 0
    Set-EdgeLane $Root 'ctx_manager' 'ctx_system' 'Dữ liệu quản lý và lệnh điều phối' 0.762 1 0.509 0
    Set-EdgeLane $Root 'ctx_manager' 'ctx_system' 'Yêu cầu xử lý sự cố, báo cáo và Agent' 0.929 1 0.539 0

    # Các dịch vụ ngoài dùng lane độc lập, không chia sẻ đoạn thẳng.
    Set-EdgeLane $Root 'ctx_system' 'ctx_map' 'Từ khóa, tọa độ và yêu cầu tìm tuyến' 0.785 0 0.196 1
    Set-EdgeLane $Root 'ctx_map' 'ctx_system' 'Bản đồ, địa điểm, phương án tuyến và ETA' 0.674 1 0.882 0
    Set-EdgeLane $Root 'ctx_system' 'ctx_ai' 'Yêu cầu suy luận và ngữ cảnh đã kiểm soát' 0.206 1 0.250 0
    Set-EdgeLane $Root 'ctx_ai' 'ctx_system' 'Kết quả suy luận' 0.750 0 0.294 1
    Set-EdgeLane $Root 'ctx_system' 'ctx_push' 'Nội dung thông báo và mã thiết bị' 0.711 1 0.250 0
    Set-EdgeLane $Root 'ctx_push' 'ctx_system' 'Mã thông điệp và lỗi nhà cung cấp' 0.750 0 0.798 1

    # Nhãn là vertex độc lập để draw.io không tự dồn chữ lên connector.
    $labels = @(
        @('ctx_label_d2a', 'Kết quả xác thực<br>và hồ sơ', 70, 390, 220, 60),
        @('ctx_label_d2b', 'Thông tin chuyến<br>và chỉ dẫn tuyến', 185, 560, 235, 65),
        @('ctx_label_d2c', 'Cảnh báo, thông báo<br>và câu trả lời', 300, 730, 235, 65),
        @('ctx_label_d1a', 'Thông tin xác thực', 350, 650, 190, 45),
        @('ctx_label_d1b', 'Xác nhận và<br>trạng thái chuyến', 425, 490, 220, 60),
        @('ctx_label_d1c', 'GPS, telemetry,<br>SOS và câu hỏi', 500, 345, 220, 60),

        @('ctx_label_d4a', 'Kết quả xác thực<br>và phân quyền', 790, 390, 220, 60),
        @('ctx_label_d4b', 'Dữ liệu đội xe và<br>giám sát realtime', 920, 560, 235, 65),
        @('ctx_label_d4c', 'Cảnh báo, sự cố,<br>báo cáo và kết quả Agent', 1030, 730, 250, 65),
        @('ctx_label_d3a', 'Thông tin xác thực', 1080, 650, 190, 45),
        @('ctx_label_d3b', 'Dữ liệu quản lý<br>và lệnh điều phối', 1160, 490, 225, 60),
        @('ctx_label_d3c', 'Yêu cầu xử lý sự cố,<br>báo cáo và Agent', 1260, 345, 235, 60),

        @('ctx_label_d5', 'Từ khóa, tọa độ và<br>yêu cầu tìm tuyến', 1660, 470, 250, 60),
        @('ctx_label_d6', 'Bản đồ, địa điểm,<br>phương án tuyến và ETA', 1940, 680, 270, 65),
        @('ctx_label_d7', 'Yêu cầu suy luận và<br>ngữ cảnh đã kiểm soát', 355, 1090, 270, 65),
        @('ctx_label_d8', 'Kết quả suy luận', 635, 1210, 190, 45),
        @('ctx_label_d9', 'Nội dung thông báo<br>và mã thiết bị', 1515, 1090, 240, 60),
        @('ctx_label_d10', 'Mã thông điệp và<br>lỗi nhà cung cấp', 1790, 1210, 240, 60)
    )
    foreach ($label in $labels) {
        Add-FlowLabel $Document $Root $label[0] $label[1] $label[2] $label[3] $label[4] $label[5]
    }
}

function Add-LegendBox {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Root,
        [string]$Id,
        [string]$Value,
        [double]$X,
        [double]$Y,
        [double]$Width,
        [double]$Height
    )

    $cell = $Document.CreateElement('mxCell')
    $cell.SetAttribute('id', $Id)
    $cell.SetAttribute('value', $Value)
    $cell.SetAttribute('style', 'rounded=1;whiteSpace=wrap;html=1;overflow=hidden;fillColor=#ffffff;strokeColor=#999999;strokeWidth=1;align=left;verticalAlign=top;spacingTop=10;spacingLeft=12;spacingRight=10;fontFamily=Arial;fontSize=13;fontColor=#202020;')
    $cell.SetAttribute('vertex', '1')
    $cell.SetAttribute('parent', '1')
    $geometry = $Document.CreateElement('mxGeometry')
    $geometry.SetAttribute('x', [string]$X)
    $geometry.SetAttribute('y', [string]$Y)
    $geometry.SetAttribute('width', [string]$Width)
    $geometry.SetAttribute('height', [string]$Height)
    $geometry.SetAttribute('as', 'geometry')
    [void]$cell.AppendChild($geometry)
    [void]$Root.AppendChild($cell)
}

function Optimize-ArchitectureEdges {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Root,
        [string]$CodePrefix,
        [string]$LegendIdPrefix,
        [double]$LegendY,
        [double]$LegendHeight,
        [string]$CaptionId,
        [double]$CaptionY
    )

    $items = @()
    $number = 0
    foreach ($edge in @($Root.mxCell | Where-Object { $_.GetAttribute('edge') -eq '1' })) {
        $description = $edge.GetAttribute('value')
        $style = $edge.GetAttribute('style')
        if ($style -notmatch 'jumpStyle=') {
            $style += 'jumpStyle=arc;jumpSize=8;'
        }
        $style = $style -replace 'fontSize=10;', 'fontSize=12;fontStyle=1;'
        $edge.SetAttribute('style', $style)
        if ([string]::IsNullOrWhiteSpace($description)) {
            continue
        }
        $number++
        $code = $CodePrefix + $number
        $edge.SetAttribute('value', $code)
        $items += [pscustomobject]@{ Code = $code; Description = $description }
    }

    $split = [int][Math]::Ceiling($items.Count / 2.0)
    $left = @($items | Select-Object -First $split)
    $right = @($items | Select-Object -Skip $split)
    $formatColumn = {
        param($Entries)
        (($Entries | ForEach-Object { '<b>' + $_.Code + '</b> — ' + $_.Description }) -join '<br><br>')
    }
    Add-LegendBox $Document $Root ($LegendIdPrefix + '_left') (& $formatColumn $left) 80 $LegendY 1090 $LegendHeight
    Add-LegendBox $Document $Root ($LegendIdPrefix + '_right') (& $formatColumn $right) 1230 $LegendY 1090 $LegendHeight
    Set-VertexGeometry $Root $CaptionId 600 $CaptionY 1200 35
}

$definitions = @(
    [pscustomobject]@{
        Prefix = 'ctx_'
        PageName = 'Hình 2.8 - Biểu đồ ngữ cảnh'
        FileName = 'hinh-2-8-bieu-do-ngu-canh.mxgraph.xml'
        DeltaY = 350
    },
    [pscustomobject]@{
        Prefix = 'logic_'
        PageName = 'Hình 2.9 - Kiến trúc tổng thể'
        FileName = 'hinh-2-9-kien-truc-tong-the.mxgraph.xml'
        DeltaY = -200
    },
    [pscustomobject]@{
        Prefix = 'deploy_'
        PageName = 'Hình 2.10 - Kiến trúc triển khai'
        FileName = 'hinh-2-10-kien-truc-trien-khai.mxgraph.xml'
        DeltaY = -820
    }
)

function New-MxGraphModelDocument {
    param(
        [string]$Prefix,
        [double]$DeltaY
    )

    $output = New-Object System.Xml.XmlDocument
    $model = $output.CreateElement('mxGraphModel')
    $attributes = [ordered]@{
        dx = '1319'
        dy = '743'
        grid = '1'
        gridSize = '10'
        guides = '1'
        tooltips = '1'
        connect = '1'
        arrows = '1'
        fold = '1'
        page = '1'
        pageScale = '1'
        pageWidth = '2400'
        pageHeight = '1800'
        math = '0'
        shadow = '0'
    }
    foreach ($attribute in $attributes.GetEnumerator()) {
        $model.SetAttribute($attribute.Key, $attribute.Value)
    }
    [void]$output.AppendChild($model)

    $root = $output.CreateElement('root')
    [void]$model.AppendChild($root)

    foreach ($baseId in @('0', '1')) {
        $baseCell = $sourceCells | Where-Object { $_.GetAttribute('id') -eq $baseId } | Select-Object -First 1
        if ($null -eq $baseCell) {
            throw "Thiếu mxCell gốc id=$baseId."
        }
        [void]$root.AppendChild($output.ImportNode($baseCell, $true))
    }

    $vertices = @($sourceCells | Where-Object {
        $_.GetAttribute('vertex') -eq '1' -and $_.GetAttribute('id').StartsWith($Prefix)
    })
    $vertexIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($vertex in $vertices) {
        [void]$vertexIds.Add($vertex.GetAttribute('id'))
        $clone = [System.Xml.XmlElement]$output.ImportNode($vertex, $true)
        $geometry = $clone.SelectSingleNode('./mxGeometry')
        if ($null -ne $geometry -and $geometry.HasAttribute('y')) {
            $newY = [double]$geometry.GetAttribute('y') + $DeltaY
            $geometry.SetAttribute('y', ([string]$newY))
        }
        [void]$root.AppendChild($clone)
    }

    $edges = @($sourceCells | Where-Object {
        $_.GetAttribute('edge') -eq '1' -and
        $vertexIds.Contains($_.GetAttribute('source')) -and
        $vertexIds.Contains($_.GetAttribute('target'))
    })
    foreach ($edge in $edges) {
        [void]$root.AppendChild($output.ImportNode($edge, $true))
    }

    if ($Prefix -eq 'ctx_') {
        Optimize-ContextDiagram -Document $output -Root $root
    }
    elseif ($Prefix -eq 'logic_') {
        Optimize-ArchitectureEdges -Document $output -Root $root -CodePrefix 'L' -LegendIdPrefix 'logic_legend' -LegendY 950 -LegendHeight 330 -CaptionId 'logic_caption' -CaptionY 1320
    }
    elseif ($Prefix -eq 'deploy_') {
        Optimize-ArchitectureEdges -Document $output -Root $root -CodePrefix 'D' -LegendIdPrefix 'deploy_legend' -LegendY 1050 -LegendHeight 410 -CaptionId 'deploy_caption' -CaptionY 1500
    }

    if ($vertices.Count -eq 0 -or $edges.Count -eq 0) {
        throw "Nhóm $Prefix không có đủ vertex/edge."
    }

    return [pscustomobject]@{
        Document = $output
        Model = $model
        VertexCount = $vertices.Count
        EdgeCount = $edges.Count
    }
}

function Save-XmlDocument {
    param(
        [System.Xml.XmlDocument]$Document,
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.OmitXmlDeclaration = $true
    $settings.NewLineChars = "`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Dispose()
    }
}

$generated = @()
foreach ($definition in $definitions) {
    $result = New-MxGraphModelDocument -Prefix $definition.Prefix -DeltaY $definition.DeltaY
    $path = Join-Path $outputRoot $definition.FileName
    Save-XmlDocument -Document $result.Document -Path $path
    $generated += [pscustomobject]@{
        Definition = $definition
        Path = $path
        Model = $result.Model
        VertexCount = $result.VertexCount
        EdgeCount = $result.EdgeCount
    }
}

# Tạo một file draw.io gồm đúng ba trang độc lập.
$drawio = New-Object System.Xml.XmlDocument
$mxfile = $drawio.CreateElement('mxfile')
$mxfile.SetAttribute('host', 'app.diagrams.net')
$mxfile.SetAttribute('pages', '3')
[void]$drawio.AppendChild($mxfile)

$pageNumber = 0
foreach ($item in $generated) {
    $pageNumber++
    $diagram = $drawio.CreateElement('diagram')
    $diagram.SetAttribute('id', ('safefleet-architecture-' + $pageNumber))
    $diagram.SetAttribute('name', $item.Definition.PageName)
    [void]$diagram.AppendChild($drawio.ImportNode($item.Model, $true))
    [void]$mxfile.AppendChild($diagram)
}

$drawioPath = Join-Path $outputRoot 'safefleet-kien-truc-3-trang.drawio'
Save-XmlDocument -Document $drawio -Path $drawioPath

# Tạo tài liệu Markdown có ba đoạn mã tách biệt để sao chép vào Edit Diagram.
$markdownPath = Join-Path $outputRoot 'MA_MXGRAPH_SO_DO_THIET_KE_HE_THONG_2_2.md'
$builder = New-Object System.Text.StringBuilder
[void]$builder.AppendLine('# Mã mxGraphModel cho các sơ đồ thiết kế SafeFleet')
[void]$builder.AppendLine('')
[void]$builder.AppendLine('Mỗi khối dưới đây là một trang độc lập. Trong diagrams.net, tạo trang mới, chọn **Extras → Edit Diagram**, thay toàn bộ nội dung bằng đúng một khối XML rồi chọn **Apply**.')
[void]$builder.AppendLine('')
foreach ($item in $generated) {
    [void]$builder.AppendLine(('## ' + $item.Definition.PageName))
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('```xml')
    [void]$builder.AppendLine((Get-Content -LiteralPath $item.Path -Raw -Encoding UTF8).Trim())
    [void]$builder.AppendLine('```')
    [void]$builder.AppendLine('')
}
[System.IO.File]::WriteAllText($markdownPath, $builder.ToString(), (New-Object System.Text.UTF8Encoding($false)))

$generated | ForEach-Object {
    Write-Output ("{0}: {1} vertex, {2} edge -> {3}" -f $_.Definition.PageName, $_.VertexCount, $_.EdgeCount, $_.Path)
}
Write-Output "File draw.io ba trang: $drawioPath"
Write-Output "Tài liệu mã XML: $markdownPath"
