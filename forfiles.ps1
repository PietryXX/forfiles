Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# FORM PRINCIPALE
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "ForFiles GUI"
$form.Size = New-Object System.Drawing.Size(560, 330)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# --- Percorso cartella (/p) ---
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Cartella (/p):"
$lblPath.Location = New-Object System.Drawing.Point(10, 20)
$lblPath.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(120, 18)
$txtPath.Size = New-Object System.Drawing.Size(340, 20)
$txtPath.Text = "C:\Windows\System32"
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(470, 16)
$btnBrowse.Size = New-Object System.Drawing.Size(30, 23)
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fbd.ShowDialog() -eq "OK") { $txtPath.Text = $fbd.SelectedPath }
})
$form.Controls.Add($btnBrowse)

# --- Maschera file (/m) ---
$lblMask = New-Object System.Windows.Forms.Label
$lblMask.Text = "Maschera (/m):"
$lblMask.Location = New-Object System.Drawing.Point(10, 55)
$lblMask.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblMask)

$txtMask = New-Object System.Windows.Forms.TextBox
$txtMask.Location = New-Object System.Drawing.Point(120, 53)
$txtMask.Size = New-Object System.Drawing.Size(340, 20)
$txtMask.Text = "notepad.exe"
$form.Controls.Add($txtMask)

# --- Comando da eseguire (/c) ---
$lblCmd = New-Object System.Windows.Forms.Label
$lblCmd.Text = "Comando (/c):"
$lblCmd.Location = New-Object System.Drawing.Point(10, 90)
$lblCmd.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblCmd)

$txtCmd = New-Object System.Windows.Forms.TextBox
$txtCmd.Location = New-Object System.Drawing.Point(120, 88)
$txtCmd.Size = New-Object System.Drawing.Size(340, 20)
$txtCmd.Text = '"@path"'
$form.Controls.Add($txtCmd)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "Usa @path / @file / @fname / @ext ecc. come nel forfiles originale."
$lblHint.Location = New-Object System.Drawing.Point(120, 110)
$lblHint.Size = New-Object System.Drawing.Size(380, 20)
$lblHint.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblHint)

# --- Anteprima comando ---
$lblPreviewTitle = New-Object System.Windows.Forms.Label
$lblPreviewTitle.Text = "Anteprima comando forfiles:"
$lblPreviewTitle.Location = New-Object System.Drawing.Point(10, 140)
$lblPreviewTitle.Size = New-Object System.Drawing.Size(250, 20)
$form.Controls.Add($lblPreviewTitle)

$txtPreview = New-Object System.Windows.Forms.TextBox
$txtPreview.Location = New-Object System.Drawing.Point(10, 160)
$txtPreview.Size = New-Object System.Drawing.Size(520, 40)
$txtPreview.Multiline = $true
$txtPreview.ReadOnly = $true
$txtPreview.BackColor = [System.Drawing.Color]::WhiteSmoke
$form.Controls.Add($txtPreview)

function Update-Preview {
    $p = $txtPath.Text
    $m = $txtMask.Text
    $c = $txtCmd.Text
    $txtPreview.Text = "forfiles /p `"$p`" /m `"$m`" /c $c"
}
$txtPath.Add_TextChanged({ Update-Preview })
$txtMask.Add_TextChanged({ Update-Preview })
$txtCmd.Add_TextChanged({ Update-Preview })
Update-Preview

# --- Output log ---
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(10, 210)
$txtLog.Size = New-Object System.Drawing.Size(520, 60)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

# --- Pulsante esecuzione ---
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Esegui"
$btnRun.Location = New-Object System.Drawing.Point(10, 280)
$btnRun.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($btnRun)

# ------------------------------------------------------------
# SIMULAZIONE DI FORFILES IN POWERSHELL
# forfiles nativo richiede privilegi/cmd.exe; qui lo "simuliamo"
# cercando i file corrispondenti alla maschera nella cartella
# indicata e lanciando il comando per ciascuno, sostituendo
# i placeholder standard di forfiles (@path, @file, @fname, @ext, @isdir, @fsize, @fdate, @ftime).
# ------------------------------------------------------------
function Invoke-ForFilesSim {
    param(
        [string]$FolderPath,
        [string]$Mask,
        [string]$CommandTemplate
    )

    if (-not (Test-Path -LiteralPath $FolderPath)) {
        throw "Il percorso '$FolderPath' non esiste."
    }

    $files = Get-ChildItem -LiteralPath $FolderPath -Filter $Mask -File -ErrorAction SilentlyContinue

    if (-not $files -or $files.Count -eq 0) {
        $txtLog.AppendText("Nessun file trovato per la maschera '$Mask' in '$FolderPath'.`r`n")
        return
    }

    foreach ($f in $files) {
        $cmd = $CommandTemplate
        $cmd = $cmd -replace '@path', [Regex]::Escape($f.FullName) -replace '\\', '\'
        $cmd = $CommandTemplate `
            -replace '@path',  $f.FullName `
            -replace '@file',  $f.Name `
            -replace '@fname', [IO.Path]::GetFileNameWithoutExtension($f.Name) `
            -replace '@ext',   $f.Extension.TrimStart('.') `
            -replace '@isdir', 'FALSE' `
            -replace '@fsize', $f.Length `
            -replace '@fdate', $f.LastWriteTime.ToString('dd/MM/yyyy') `
            -replace '@ftime', $f.LastWriteTime.ToString('HH:mm:ss')

        $txtLog.AppendText("Eseguo: cmd /c $cmd`r`n")
        try {
            # Esegue il comando tramite cmd.exe, come fa forfiles realmente
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -NoNewWindow -Wait
            $txtLog.AppendText(" -> OK ($($f.Name))`r`n")
        }
        catch {
            $txtLog.AppendText(" -> ERRORE su $($f.Name): $($_.Exception.Message)`r`n")
        }
    }
}

$btnRun.Add_Click({
    $txtLog.Clear()
    try {
        Invoke-ForFilesSim -FolderPath $txtPath.Text -Mask $txtMask.Text -CommandTemplate $txtCmd.Text
        $txtLog.AppendText("`r`nCompletato.`r`n")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Errore", "OK", "Error") | Out-Null
    }
})

[void]$form.ShowDialog()
