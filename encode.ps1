<#
.SYNOPSIS
Ce script permet de réencoder tous les fichiers vidéo du dossier courant ou du fichier passé en paramètre en utilisant différents codecs (AV1, HEVC, AVC).

.DESCRIPTION
Le choix du codec dépend de la carte graphique présente sur l'ordinateur.
Si la carte graphique est une Nvidia Ada Lovelace (4XXX) ou supérieure (modèle commençant par 60 ou 70), le codec utilisé sera AV1.
Si la carte graphique est une Nvidia Pascal/Turing/Ampere (1/2/3XXX) (modèle commençant par 60 ou 70), le codec utilisé sera HEVC (H265).
Pour les autres cartes graphiques, le codec utilisé sera AVC (H264).
Les fichiers déjà réencodés avec ces codecs ou avec HandBrake HEVC ne seront pas pris en compte.

.PARAMETER FilePath
Paramètre facultatif. Chemin du fichier vidéo à réencoder. Si aucun chemin n'est spécifié, tous les fichiers vidéo du dossier courant et ses sous-dossiers seront réencodés.

.PARAMETER Qualité
Paramètre facultatif pour spécifier la qualité du réencodage. La valeur doit être un entier entre 0 et 51. 0 étant la mode automatique. 1 étant la meilleure qualité et 51 la meilleur compression. La valeur par défaut est 0.

.PARAMETER AV1
Paramètre facultatif pour forcer l'utilisation du codec AV1 (AOMedia Video Codec).

.PARAMETER HEVC
Paramètre facultatif pour forcer l'utilisation du codec HEVC (H265).

.PARAMETER AVC
Paramètre facultatif pour forcer l'utilisation du codec AVC (H264).

.PARAMETER Debut
Paramètre facultatif pour spécifier le point de départ de la vidéo réencodée (équivalent à l'option -ss de FFmpeg).

.PARAMETER Fin
Paramètre facultatif pour spécifier la durée de la vidéo réencodée (équivalent à l'option -t de FFmpeg).

.PARAMETER Copy
Paramètre facultatif. Si spécifié, les paramètres liés à la vidéo seront remplacés par "-c:v", "copy".

.EXAMPLE
.\encode.ps1
Réencode tous les fichiers vidéo du dossier courant et les sous dossiers en utilisant le codec approprié.

.\encode.ps1 C:\Videos\MaVideo.mp4
Réencode le fichier vidéo spécifié en utilisant le codec approprié avec une qualité par défaut.

.\encode.ps1 C:\Videos\MaVideo.mp4 -av1
Réencode le fichier vidéo spécifié en utilisant le codec av1.

.\encode.ps1 C:\Videos\MaVideo.mp4 6
Réencode le fichier vidéo spécifié en utilisant le codec approprié avec une qualité fixé à 6.

.\encode.ps1 C:\Videos\ -avc -qualité 18
Réencode tous les fichiers vidéo du dossier courant et les sous dossiers en utilisant le codec AVC H264 avec une qualité fixé à 18.

.\encode.ps1 C:\Videos\video.mov -copy -debut 00:35:05
Réencode le fichier vidéo spécifié en réutilisant le même codec en commençant à partir de 00 heures 35 minutes et 05 secondes

.\encode.ps1 C:\Videos\video.mov -hevc -debut 01:00:30 -fin 02:00:30
Réencode le fichier vidéo spécifié en utilisant le codec hevc en commençant à partir de 01 heures 00 minutes et 30 secondes et en finissant à 02 heures 00 minutes et 30 secondes.


.NOTES
Auteur : Erwan Hervé
#>
# Définition des paramètres en entrée : -Qualité de type int et -FilePath de type string.
# Définition des paramètres en entrée.
param (
    [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
    [object[]]$Arguments,
    [switch]$AV1,
    [switch]$HEVC,
    [switch]$AVC,
    [switch]$copy,
    [string]$Debut,
    [string]$Fin
)

# Initialisation des variables.
$FilePath = $null
$Qualité = 0

# Vérifier si des arguments ont été passés.
if ($Arguments) {
    # Parcourir les arguments pour détecter le type et les associer aux paramètres correspondants.
    $remainingArgs = @()
    foreach ($arg in $Arguments) {
        if ($arg -is [int]) {
            $Qualité = $arg
        }
        elseif ($arg -is [string] -and ($arg -ne '-Debut' -and $arg -ne '-Fin')) {
            $FilePath = $arg
        }
        else {
            # Les arguments -Debut et -Fin ne sont pas associés aux variables $FilePath, nous les stockons dans $remainingArgs
            $remainingArgs += $arg
        }
    }
    # Remettre les arguments -Debut et -Fin dans la variable $Arguments pour le traitement ultérieur
    $Arguments = $remainingArgs
}

# Vérifier si le paramètre -Qualité est supérieur à 51. La valeur maximale est 51.
if ($Qualité -gt 51) {
    Write-Host "Le paramètre -Qualité ne doit pas dépasser 51." -ForegroundColor Magenta
    $Qualité = 51
}
# Vérifier si le paramètre Qualité est spécifié. Sinon, utiliser la valeur par défaut 0.
if ($Qualité) {
    Write-Host "La qualité choisie est $Qualité" -ForegroundColor DarkGray
}
elseif ($copy) {
    $Qualité=$false
}
else {
    Write-Host "Paramètre -Qualité non renseigné, valeur par défaut : $Qualité" -ForegroundColor DarkGray
}

# Définition des codecs
$Codecs = @{
    "AV1" = "av1_nvenc"
    "HEVC" = "hevc_nvenc"
    "AVC" = "h264_nvenc"
}

# Importer le module CIM pour récupérer les informations sur la carte graphique.
Import-Module CIM -ErrorAction SilentlyContinue

# Récupérer le nom de la carte graphique.
$GPU = Get-CimInstance -ClassName CIM_VideoController | Select-Object -ExpandProperty Name

# Vérifier si le paramètre AV1 est spécifié. Utiliser le codec AV1.
if ($GPU -match ".*[4-9]\d\d\d.*" -and $AV1 -and !$copy) {
    Write-Host "Le codec choisi est AV1" -ForegroundColor DarkGray
    $Codec = $Codecs["AV1"]
}
# Vérifier si le paramètre AVC est spécifié. Utiliser le codec AVC.
elseif ($AVC -and !$copy) {
    Write-Host "Le codec choisi est AVC (H264)" -ForegroundColor DarkGray
    $Codec = $Codecs["AVC"]
}
# Vérifier si le paramètre HEVC est spécifié. Utiliser le codec HEVC (H265).
elseif ($HEVC -and !$copy) {
    Write-Host "Le codec choisi est HEVC (H265)" -ForegroundColor DarkGray
    $Codec = $Codecs["HEVC"]
}
# Si aucun des paramètres AV1, HEVC, AVC n'est spécifié, utiliser le codec HEVC par défaut.
elseif (!$AV1 -and !$HEVC -and !$AVC -and !$copy) {
    if ($GPU -match ".*[2-9]\d\d\d.*") {
        Write-Host "Aucun codec choisi, le codec par défaut est HEVC (H265)" -ForegroundColor DarkGray
        $Codec = $Codecs["HEVC"]
    }
    else {
        Write-Host "Aucun codec choisi, le codec par défaut est AVC (H264)" -ForegroundColor DarkGray
        $Codec = $Codecs["AVC"]
    }
}
# Si -copy est spécifié, ne pas utiliser de codec.
elseif ($copy) {
    Write-Host "Pas de codec -copy renseigné" -ForegroundColor DarkGray
    $Codec = $false
}
if ($FilePath) {
    $IsDirectory = Test-Path -Path $FilePath -PathType Container
}
# Vérifier si le chemin spécifié est un dossier

# Vérifier si aucun chemin de fichier n'est spécifié.
if (!$FilePath -or $IsDirectory) {
    # Obtenir le chemin du dossier courant
    if (!$FilePath) {
        $FolderPath = Get-Location
    }
    else {
        $FolderPath  = $FilePath
    }


    # Obtenir tous les fichiers du dossier
    $Files = Get-ChildItem $FolderPath -Recurse

    # Filtrer les fichiers en ne gardant que les fichiers vidéo et pour ne pas réencoder en boucle les mêmes fichiers
    $VideoFiles = $Files | Where-Object {
        ($_.Extension -eq ".mp4" -or $_.Extension -eq ".avi" -or $_.Extension -eq ".mkv" -or $_.Extension -eq ".mov" -or $_.Extension -eq ".mts") -and $_.BaseName -notlike "*$($Codecs["AV1"])*" -and $_.BaseName -notlike "*HANDBRAKE HEVC*" -and $_.BaseName -notlike "*HEVC*" -and $_.BaseName -notlike "*COPY*" -and $_.BaseName -notlike "*CUTTED*" -and $_.BaseName -notlike "*av1*" -and $_.BaseName -notlike "*$($Codecs["HEVC"])*" -and $_.BaseName -notlike "*$($Codecs["AVC"])*"
    }
}
else {
    # Obtenir le chemin du fichier passé en paramètre
    if (Test-Path $FilePath) {
        $VideoFiles = Get-Item $FilePath
    }
}

# Vérifier si aucun fichier vidéo compatible n'a été trouvé.
if (!$VideoFiles) {
    Write-Host "Aucun fichier vidéo compatible trouvé dans les dossiers" -ForegroundColor Red
    exit 1
}
# Vérifier si plusieurs fichiers vidéo ont été trouvés.
elseif (($VideoFiles | Measure-Object).Count -ge 2) {
    # Afficher les noms des fichiers vidéo qui vont être réencodés.
    Write-Host -ForegroundColor DarkYellow "Les vidéos qui vont être réencodées sont : "
    $VideoFiles | ForEach-Object {
        Write-Host $_.Name -ForegroundColor Yellow
    }
}

# Réencoder chaque fichier vidéo trouvé.
$VideoFiles | Foreach-Object {
    $CQ = $Qualité
    if ($_.Extension -eq ".mkv") {
        $outputFormat = "matroska"
        $extension = "mkv"
        $subtitleCodec="copy"
    }
    else {
        $outputFormat = "mp4"
        $extension= $outputFormat
        $subtitleCodec="MOV_TEXT"
    }

    $audiojson = ffprobe.exe -hide_banner -loglevel warning -of json -show_streams -select_streams a -i "$($_.FullName)" | ConvertFrom-Json
    $subtitlejson = ffprobe.exe -hide_banner -loglevel warning -of json -show_streams -select_streams s -i "$($_.FullName)" | ConvertFrom-Json

    # Parcourir les flux de sous-titres et de pistes audio pour extraire les métadonnées
    $subtitleMetadata = @()
    $audioMetadata = @()


    foreach ($stream in $audiojson.streams) {
        if ($stream.codec_type -eq "audio") {
        # echo $stream
            if ($stream.tags.language) {
                    $audioMetadata += "-metadata:s:a:$($audiojson.streams.IndexOf($stream))", "language=$($stream.tags.language)"
            }
            if ($stream.tags.title) {
                $audioMetadata += "-metadata:s:a:$($audiojson.streams.IndexOf($stream))", "title=`"$($stream.tags.title)`""
            }
        }
    }


    foreach ($stream in $subtitlejson.streams) {
        if ($stream.codec_type -eq "subtitle") {
        # echo $stream
            if ($stream.tags.language) {
                $subtitleMetadata += "-metadata:s:s:$($subtitlejson.streams.IndexOf($stream))", "language=$($stream.tags.language)"
            }
            if ($stream.tags.title) {
            $subtitleMetadata += "-metadata:s:s:$($subtitlejson.streams.IndexOf($stream))", "title=`"$($stream.tags.title)`""
            $subtitleMetadata += "-metadata:s:s:$($subtitlejson.streams.IndexOf($stream))", "handler_name=`"$($stream.tags.title)`""
            $subtitleMetadata += "-metadata:s:s:$($subtitlejson.streams.IndexOf($stream))", "handler=`"$($stream.tags.title)`""
            }
        }
}
    # Lancer le processus de réencodage en utilisant ffmpeg avec les paramètres spécifiés.
    $ffmpegArgs = @(
        "-hide_banner",
        "-hwaccel auto",
        # "-filter_hw_device cuda",
        "-i", "`"$($_.FullName)`"",
        "-c:a", "copy",
        "-c:s", "$subtitleCodec",
        "-y",
        "-loglevel", "warning",
        "-stats",
        "-map", "0",
        "-map_metadata", "0",
        "-map_chapters", "0",
        "-movflags", "use_metadata_tags",
        "-movflags", "faststart"
        # "-r", "60",
    )
    $ffmpegArgs += $subtitleMetadata
    $ffmpegArgs += $audioMetadata
# Vérifier si le paramètre -Copy est spécifié.
if ($Copy -and $Codec) {
    # Si le paramètre -Copy est spécifié, remplacer les paramètres vidéo par "-c:v", "copy"
    $VideoArgs = "-c:v", "copy"
}
else {
    # Sinon, utiliser les autres paramètres vidéo
    $VideoArgs = @(
        "-c:v", "$($Codec)",
        "-preset:v", "18",
        # "-tier:v", "1",
        #"-profile:v", "1",
        # "-2pass", "true",
        # "-multipass", "2",
        # "-weighted_pred", "1",
        "-b_ref_mode", "2",
        "-temporal_aq", "1",
        "-rc-lookahead", "55",
        "-spatial_aq", "1",
        "-nonref_p", "1",
        "-cq:v", "$CQ",
        "-tune", "1",
        "-f", "$outputFormat"
    )
}

# Ajouter les arguments vidéos
$ffmpegArgs += $VideoArgs

# Vérifier si le paramètre -Debut est spécifié. Si oui, ajouter le paramètre -ss à la commande FFmpeg.
if ($Debut) {
    $ffmpegArgs += "-ss", "$Debut"
}

# Vérifier si le paramètre -Fin est spécifié. Si oui, ajouter le paramètre -to à la commande FFmpeg.
if ($Fin) {
    $ffmpegArgs += "-to", "$Fin"
}
if ($copy -and !($Debut -and $Fin)) {
    $end="COPY"
}
elseif ($copy -and ($Debut -or $Fin)) {
    $end="CUTTED"
}
else {
    # Afficher le message de réencodage en cours avec les détails du fichier et du codec utilisé.
    Write-Host "Réencodage en cours : $($_.Name) avec le codec $($Codec) en qualité $CQ" -ForegroundColor Blue
    $end="$($Codec.toupper().Split('_')[0])_$CQ"
}
# Ajouter l'output à la fin
$ffmpegArgs += "`"$($_.Directory)\$($_.BaseName) - $($end).$($extension)`""

$ffmpegSplat = @{
    "FilePath" = "ffmpeg.exe"
    "ArgumentList" = $ffmpegArgs
    "NoNewWindow" = $true
    "Wait" = $true
}

Start-Process @ffmpegSplat

    # Vérifier si le réencodage s'est terminé avec succès.
    if ($?) {
        Write-Host "Réencodage terminé : $($_.Directory)\$($_.BaseName) - $($end).$($extension)" -ForegroundColor Green
    }
}
