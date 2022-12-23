# Ce script permet de réencoder tous les fichiers vidéo du dossier courant ou du fichier passé en paramètre en utilisant le codec av1, h265 ou h264.
# Le choix du codec dépend de la carte graphique présente sur l'ordinateur.
# Si la carte graphique est une Nvidia Ada Lovelace (4XXX) ou supérieure (modèle commençant par 60 ou 70), le codec utilisé sera av1.
# Sinon la carte graphique est une Nvidia Pascal/Turing/Ampere (1/2/3XXX) (modèle commençant par 60 ou 70), le codec utilisé sera h265. (Pour la génération Pascal les B-frames ne sont pas compatible)
# Sinon le codec utilisé sera h264.
# Les fichiers déjà réencodés avec ces codecs ou avec HandBrake HEVC ne seront pas pris en compte.
# Le bitrate utilisé par défaut pour le réencodage sera la moitié du bitrate original, arrondi à l'entier supérieur.
# Exemple d'utilisation :
# .\reencode-video.ps1
# .\reencode-video.ps1 C:\Videos\MaVideo.mp4
# Auteur : Erwan Hervé
# Définition d'un paramètre en entrée $FilePath de type string. Si aucune valeur n'est passée, il prend la valeur $null.
param (
    [string]$FilePath = $null
)
# Définition de trois variables qui contiennent les chaînes de caractères "av1_nvenc", "hevc_nvenc" et "h264_nvenc".
$av1="av1_nvenc"
$hevc="hevc_nvenc"
$avc="h264_nvenc"
Import-Module CIM -ErrorAction SilentlyContinue
$gpu = Get-CimInstance -ClassName CIM_VideoController | Select-Object -ExpandProperty Name
if ($gpu -match ".*4\d\d\d$")
{
    $nvenc= $av1
}
elseif ($gpu -match ".*[1-3]\d\d\d$")
{
    $nvenc= $hevc
}
else {
    $nvenc= $avc
}

if (!$FilePath) {
    # Obtenir le chemin du dossier courant
    $folderPath = Get-Location

    # Obtenir tous les fichiers du dossier
    $files = Get-ChildItem $folderPath -Recurse

    # Filtrer les fichiers en ne gardant que les fichiers vidéo et pour ne pas réencoder en boucle les mêmes fichiers
    $videoFiles = $files | Where-Object { ($_.Extension -eq ".mp4" -or $_.Extension -eq ".avi" -or $_.Extension -eq ".mkv") -and $_.BaseName -notlike "*_$av1" -and $_.BaseName -notlike "*HANDBRAKE HEVC*" -and $_.BaseName -notlike "*_av1" -and $_.BaseName -notlike "*_$hevc" -and $_.BaseName -notlike "*_$avc"}
    Write-Output "Les vidéos qui vont être réencodés sont : " $videoFiles | Format-Table
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
    Write-Host "Aucun fichier vidéo ne correspond aux filtres"
}
else
{
    # Convertir les fichiers vidéo
    $videoFiles | Foreach-Object {
        $oldbitrate = ffmpeg -hide_banner -i "$($_.fullname)" -f null /dev/null - 2>&1 | ForEach-Object { if ($_ -match "bitrate: (\d+)") { Write-Output $Matches[1] } }
        if ($oldbitrate -ge 55000) {
            $divide= 4.5
        }
        elseif ($oldbitrate -ge 45000) {
            $divide= 4
        }
        elseif ($oldbitrate -ge 35000) {
            $divide= 3.5
        }
        elseif ($oldbitrate -ge 25000) {
            $divide= 3
        }
        elseif ($oldbitrate -ge 15000) {
            $divide= 2.5
        }
        else {
            $divide= 2
        }
        $bitrate = [math]::Ceiling($oldbitrate / $divide)
        write-output "Réencondage en cours : $($_.Name) en $($nvenc) $($bitrate)KB/s au lieu de $($oldbireate)KB/s"
        Start-Process -NoNewWindow -Wait -FilePath "ffmpeg.exe" -ArgumentList "-hide_banner -i `"$($_.fullname)`" -c:a copy -preset slow -b_ref_mode middle -temporal-aq 1 -rc-lookahead 35 -spatial-aq 1 -c:v $($nvenc) -y -b:v $($bitrate)k -crf 24 `"$($_.directory)\$($_.basename)_$($nvenc).mp4`""
    }
}
