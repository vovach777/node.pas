# Список файлов для анализа
$files = @("np.OpenSSL.pas", "np.http_parser.pas", "np.libuv.pas")
$outputFile = "nodepaslib.def"

$allNames = @()

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Processing file: $file..."
        $content = Get-Content $file
        foreach ($line in $content) {
            # Skip comments and $EXTERNALSYM
            if ($line -match '^\s*//' -or $line -match '\{\$EXTERNALSYM') { continue }

            # Regex for function/procedure name before external
            if ($line -match '(?:function|procedure)\s+([a-zA-Z0-9_]+).*external') {
                $allNames += $Matches[1]
            }
        }
    } else {
        Write-Warning "File not found: $file"
    }
}

# Unique and sort
$uniqueNames = $allNames | Sort-Object -Unique

# Build .def file
$defContent = New-Object System.Collections.Generic.List[string]
$null = $defContent.Add("EXPORTS")
foreach ($name in $uniqueNames) {
    $null = $defContent.Add("  $name")
}

# Save as ASCII
[System.IO.File]::WriteAllLines((Get-Item .).FullName + "\" + $outputFile, $defContent, [System.Text.Encoding]::ASCII)

Write-Host "`nDone!"
Write-Host "File $outputFile updated. Total names: $($uniqueNames.Count)"
