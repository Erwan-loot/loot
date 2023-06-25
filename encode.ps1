# Ce script permet de réencoder tous les fichiers vidéo du dossier courant ou du fichier passé en paramètre en utilisant le codec av1, h265 ou h264.
# Le choix du codec dépend de la carte graphique présente sur l'ordinateur.
# Si la carte graphique est une Nvidia Ada Lovelace (4XXX) ou supérieure (modèle commençant par 60 ou 70), le codec utilisé sera av1.
# Sinon la carte graphique est une Nvidia Pascal/Turing/Ampere (1/2/3XXX) (modèle commençant par 60 ou 70), le codec utilisé sera h265. (Pour la génération Pascal les B-frames ne sont pas compatible)
# Sinon le codec utilisé sera h264.
# Les fichiers déjà réencodés avec ces codecs ou avec HandBrake HEVC ne seront pas pris en compte.
# Exemple d'utilisation :
# .\reencode-video.ps1
# .\reencode-video.ps1 C:\Videos\MaVideo.mp4
# Auteur : Erwan Hervé
# Définition d'un paramètre en entrée $FilePath de type string. Si aucune valeur n'est passée, il prend la valeur $null.
param (
    [string]$FilePath = $null,
    [int]$qualité,
    [switch]$avc,
    [switch]$hevc,
    [switch]$av1
)
if ($qualité -gt 51) {
    Write-Host "Le paramètre qualité ne doit pas dépasser 51." -ForegroundColor Magenta
    $qualité = 51
}
if ($qualité) {
    Write-Host "La qualité choisie est $qualité" -ForegroundColor DarkGray
}
else {
    $qualité=28
    Write-Host "Paramètre -qualité non renseigné, valeur par défaut : $qualité" -ForegroundColor DarkGray
}
# Définition de trois variables qui contiennent les chaînes de caractères "av1_nvenc", "hevc_nvenc" et "h264_nvenc".
$av1_nvenc="av1_nvenc"
$hevc_nvenc="hevc_nvenc"
$avc_nvenc="h264_nvenc"
Import-Module CIM -ErrorAction SilentlyContinue
$gpu = Get-CimInstance -ClassName CIM_VideoController | Select-Object -ExpandProperty Name
if (!$av1 -and !$hevc -and !$avc)
{
    Write-Host "Aucun codec choisi, il sera determiné en fonction du GPU" -ForegroundColor DarkGray
    $codec = $false
}
# if (($gpu -match ".*[4-9]\d\d\d$" -and !$codec) -or $av1)
if ($av1)
{
    Write-Host "Le codec choisi est AV1" -ForegroundColor DarkGray
    $codec=$av1_nvenc
}
elseif (($gpu -match ".*[2-9]\d\d\d$" -and !$codec) -or $hevc)
{
    Write-Host "Le codec choisi est HEVC (H265)" -ForegroundColor DarkGray
    $codec=$hevc_nvenc
}
else
{
    Write-Host "Le codec choisi est AVC (H264)" -ForegroundColor DarkGray
    $codec=$avc_nvenc
}

if (!$FilePath) {
    # Obtenir le chemin du dossier courant
    $folderPath = Get-Location

    # Obtenir tous les fichiers du dossier
    $files = Get-ChildItem $folderPath -Recurse

    # Filtrer les fichiers en ne gardant que les fichiers vidéo et pour ne pas réencoder en boucle les mêmes fichiers
    $videoFiles = $files | Where-Object { ($_.Extension -eq ".mp4" -or $_.Extension -eq ".avi" -or $_.Extension -eq ".mkv") -and $_.BaseName -notlike "*_$av1_nvenc*" -and $_.BaseName -notlike "*HANDBRAKE HEVC*" -and $_.BaseName -notlike "*HEVC*"-and $_.BaseName -notlike "*_av1" -and $_.BaseName -notlike "*_$hevc_nvenc*" -and $_.BaseName -notlike "*_$avc_nvenc*"}
}
else {
    # Obtenir le chemin du fichier passé en paramètre
    if (Test-Path $FilePath)
    {
        $videoFiles = Get-Item $FilePath
    }
}
if (!$videoFiles)
{
    Write-Host "Aucun fichier vidéo ne correspond aux filtres" -ForegroundColor Red
}
else
{
    # Convertir les fichiers vidéo
    Write-Host -ForegroundColor Yellow "Les vidéos qui vont être réencodés sont : "
    $videoFiles | ForEach-Object {
        Write-Host $_.Name -ForegroundColor Green
    }

     $videoFiles | Foreach-Object {
        $cq=$qualité
        write-host "Réencondage en cours : $($_.Name) avec le codec $($codec) en qualité $cq" -ForegroundColor Blue
        Start-Process -NoNewWindow -Wait -FilePath "ffmpeg.exe" -ArgumentList "-hide_banner -i `"$($_.fullname)`" -c:a copy -c:s copy -tune 1 -preset:v 1  -b_ref_mode 2  -temporal-aq 1  -rc-lookahead 35  -spatial-aq 1  -multipass 2  -c:v $($codec) -2pass true -y -crf 30 -loglevel error -stats -cq:v $cq -nonref_p 1 -f mp4 `"$($_.directory)\$($_.basename)_$($codec)_$cq.mp4`""
     }
}
