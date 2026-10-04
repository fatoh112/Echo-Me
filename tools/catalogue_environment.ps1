$ErrorActionPreference = 'Stop'
$echoProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$echoPackRoot = Join-Path $echoProjectRoot 'assets/environment/slavic_town'
$echoRows = @()
foreach ($echoFile in Get-ChildItem -LiteralPath $echoPackRoot -Filter '*.glb' -File -Recurse) {
    $echoStream = [IO.BinaryReader]::new([IO.File]::OpenRead($echoFile.FullName))
    try {
        if ($echoStream.ReadUInt32() -ne 0x46546C67) { throw 'Invalid GLB header' }
        $echoStream.ReadBytes(8) | Out-Null
        $echoJsonLength = $echoStream.ReadUInt32()
        $echoStream.ReadUInt32() | Out-Null
        $echoJson = [Text.Encoding]::UTF8.GetString($echoStream.ReadBytes($echoJsonLength)) | ConvertFrom-Json
    } finally { $echoStream.Dispose() }
    $echoName = $echoFile.BaseName
    $echoCategory = switch -Regex ($echoName) {
        'Administrative' { 'complete buildings'; break }
        'Tover|Tower' { 'watch structures'; break }
        'Roof' { 'roofs'; break }
        'Hut_Wall|Hut_Foundation|Hut_Ceiling' { 'modular walls'; break }
        'Shutter' { 'windows'; break }
        'Door|Bolt' { 'doors'; break }
        'Stair|Step|Porch|platform' { 'stairs'; break }
        'Fence|Wooden_Pin' { 'fences'; break }
        'Road|Terrain|Environment|Env_' { 'roads / ground'; break }
        'Barrel' { 'barrels'; break }
        'Crate|Chest' { 'crates'; break }
        'Sign|Sheet' { 'signs'; break }
        'Nature|Plant|Grass' { 'vegetation'; break }
        'Bench' { 'benches'; break }
        'Whell' { 'well candidate'; break }
        'OutBuilding|Hovel|Balcony|Village_Fence' { 'outbuildings'; break }
        'Cube' { 'unnamed exports'; break }
        default { 'market / household props' }
    }
    $echoBounds = @()
    foreach ($echoMesh in $echoJson.meshes) {
        foreach ($echoPrimitive in $echoMesh.primitives) {
            $echoAccessor = $echoJson.accessors[$echoPrimitive.attributes.POSITION]
            $echoBounds += @{ min = $echoAccessor.min; max = $echoAccessor.max; vertices = $echoAccessor.count; mesh = $echoMesh.name }
        }
    }
    $echoRows += [pscustomobject][ordered]@{
        file = $echoFile.FullName.Substring($echoProjectRoot.Length + 1).Replace('\','/')
        category = $echoCategory
        bytes = $echoFile.Length
        nodes = @($echoJson.nodes)
        meshes = $echoBounds
        materials = @($echoJson.materials)
        images = @($echoJson.images | Select-Object name,mimeType,uri)
        textures = @($echoJson.textures)
    }
}
$echoOutputRoot = Join-Path $echoProjectRoot 'data/environment'
New-Item -ItemType Directory -Path $echoOutputRoot -Force | Out-Null
$echoOutput = $echoRows | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText((Join-Path $echoOutputRoot 'slavic_town_sources.json'), $echoOutput + "`n", [Text.UTF8Encoding]::new($false))
$echoRows | Group-Object category | Select-Object Name,Count | Format-Table
$echoRows.materials.name | Sort-Object -Unique
$echoRows.images.name | Sort-Object -Unique
