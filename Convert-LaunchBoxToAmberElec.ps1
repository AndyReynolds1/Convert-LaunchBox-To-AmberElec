# Variables
$launchBoxExportRoot = "[PATH TO LAUNCHBOX]\LaunchBox\Metadata\TEMP\Android Export\LaunchBox"
$outputFolderRoot = "$($launchBoxExportRoot)\AmberElec"

# Clean output folder
if ((Test-Path $outputFolderRoot) -eq $true) {
	Remove-Item -Path $outputFolderRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outputFolderRoot | Out-Null

# Map LaunchBox platform names to folder names used in AmberElec - https://amberelec.org/systems/
$systemToFolders = @{
	"Atari Lynx" 							= "atarilynx";
	"Commodore 64" 							= "c64";
	"Commodore Amiga"						= "amiga";
	"MAME"									= "mame";
	"Nintendo 64" 							= "n64";
	"Nintendo DS"							= "nds";
	"Nintendo Game Boy" 					= "gb";
	"Nintendo Game Boy Color"				= "gbc";
	"Nintendo Game Boy Advance"				= "gba";
	"Nintendo Entertainment System"			= "nes";
	"Sega 32X"								= "sega32x";
	"Sega Game Gear"						= "gamegear";
	"Sega Genesis"							= "megadrive";
	"SNK Neo Geo Pocket Color"				= "ngpc";
	"Sony Playstation"						= "psx";
	"Sony PSP"								= "psp";
	"Super Nintendo Entertainment System" 	= "snes";
}

function ConvertXmlFile
(
	[string]$originalXmlFile
){
	Write-Output "Converting $($xmlFile)"
	
	# Open XML file
	[xml]$originalXmlDoc = Get-Content $originalXmlFile -Encoding UTF8
	
	# Read platform name
	$platformName = $originalXmlDoc.LaunchBox.Platform.Name
	
	# Get AmberElec folder name for this system
	$systemFolder = $systemToFolders.$platformName
	
	# Create output folders
	New-Item -ItemType Directory -Force -Path "$($outputFolderRoot)\$($systemFolder)" | Out-Null
	New-Item -ItemType Directory -Force -Path "$($outputFolderRoot)\$($systemFolder)\images" | Out-Null
	New-Item -ItemType Directory -Force -Path "$($outputFolderRoot)\$($systemFolder)\videos" | Out-Null
	
	$outputFilePath = "$($outputFolderRoot)\$($systemFolder)\gamelist.xml"
	
	Write-Output "Platform folder is $($systemFolder)"
	
	# Create & Set The Formatting with XmlWriterSettings class
	$xmlObjectsettings = New-Object System.Xml.XmlWriterSettings
	#Indent: Gets or sets a value indicating whether to indent elements.
	$xmlObjectsettings.Indent = $true
	#Gets or sets the character string to use when indenting. This setting is used when the Indent property is set to true.
	$xmlObjectsettings.IndentChars = "    "
 
	# Set the File path & Create The Document
	$XmlFilePath = $outputFilePath
	$XmlObjectWriter = [System.XML.XmlWriter]::Create($XmlFilePath, $xmlObjectsettings)
 
	# Write the XML declaration and set the XSL
	#$XmlObjectWriter.WriteStartDocument()
  
	# Start the Root Element and build with child nodes
	$XmlObjectWriter.WriteStartElement("gameList")
  
	# Read all games in XML file	
	$allLaunchBoxGames = $originalXmlDoc.LaunchBox.Game
	
	ForEach ($game in $allLaunchBoxGames) {
		
		Write-Output "Processing $($game.Title)" 
		
		$XmlObjectWriter.WriteStartElement("game")
		
		$XmlObjectWriter.WriteElementString("name",$game.Title)
		$XmlObjectWriter.WriteElementString("path",(CopyGameFile $game.ApplicationPath $systemFolder))

		if ($game.Developer -ne $null) {
			$XmlObjectWriter.WriteElementString("developer",$game.Developer)
		}
		if ($game.Notes -ne $null) {
			$XmlObjectWriter.WriteElementString("desc",$game.Notes)
		}
		if ($game.Genre -ne $null) {
			$XmlObjectWriter.WriteElementString("genre",$game.Genre)
		}
		if ($game.MaxPlayers -ne $null) {
			$XmlObjectWriter.WriteElementString("players",$game.MaxPlayers)
		}
		if ($game.Publisher -ne $null) {
			$XmlObjectWriter.WriteElementString("publisher",$game.Publisher)
		}
		if ($game.ReleaseDate -ne $null) {
			$XmlObjectWriter.WriteElementString("releasedate",(ConvertDateTime $game.ReleaseDate))
		}
		if (($game.AndroidBoxFrontThumbPath -ne $null) -and ($game.AndroidBoxFrontThumbPath -ne "")) {
			$XmlObjectWriter.WriteElementString("thumbnail",(CopyImage $game.AndroidBoxFrontThumbPath $systemFolder "box"))
		}
		if (($game.AndroidGameplayScreenshotThumbPath -ne $null) -and ($game.AndroidGameplayScreenshotThumbPath -ne "")) {
			$XmlObjectWriter.WriteElementString("image",(CopyImage $game.AndroidGameplayScreenshotThumbPath $systemFolder "screenshot"))
		}
		if (($game.AndroidVideoPath -ne $null) -and ($game.AndroidVideoPath -ne "")) {
			$XmlObjectWriter.WriteElementString("video",(CopyVideoFile $game.AndroidVideoPath $systemFolder))
		}

		if (($game.StarRatingFloat -ne $null) -and ($game.StarRatingFloat -ne 0)) {
			$XmlObjectWriter.WriteElementString("rating", $game.StarRatingFloat)
		} else {
			
			if ($game.CommunityStarRating -ne $null) {
				$XmlObjectWriter.WriteElementString("rating",(CalculateRating $game.CommunityStarRating))
			}
		}
		
		$XmlObjectWriter.WriteElementString("favorite",$game.Favorite)

		$XmlObjectWriter.WriteEndElement()
	}
	 
	# Finally close the XML Document
	$XmlObjectWriter.WriteEndDocument()
	$XmlObjectWriter.Flush()
	$XmlObjectWriter.Close()
}

function CalculateRating
(
	[double]$rating
){
	return ($rating / 5)
}

function CopyGameFile
(
	[string]$file,
	[string]$systemFolder
){
	$pathParts = $file.split("/")
	
	# Copy video file to system folder
	Copy-Item -literalpath "$($launchBoxExportRoot)\$($file)" -Destination "$($outputFolderRoot)\$($systemFolder)\$($pathParts[2])"
	
	return "./$($pathParts[2])"
}

function CopyImage
(
	[string]$file,
	[string]$systemFolder,
	[string]$imageType
){
	if ((Test-Path -literalpath "$($launchBoxExportRoot)\$($file)") -eq $false) {
		Write-Warning "$($imageType.ToUpper()) IMAGE NOT FOUND!"
		return $null
	} else {
		
		$pathParts = $file.split("/")
		$filename = $pathParts[3].Substring(0,$pathParts[3].LastIndexOf("."))
		$fileExtension = $pathParts[3].Substring($pathParts[3].LastIndexOf(".")+1)

		$newFileName = "$($filename)-$($imageType).$($fileExtension)"
		
		# Copy video file to system folder
		Copy-Item -Path "$($launchBoxExportRoot)\$($file)" -Destination "$($outputFolderRoot)\$($systemFolder)\images\$($newFileName)"
		
		return "./images/$($newFileName)"
	}
}

function CopyVideoFile
(
	[string]$file,
	[string]$systemFolder
){
	if ((Test-Path -literalpath "$($launchBoxExportRoot)\$($file)") -eq $false) {
		Write-Warning "VIDEO NOT FOUND!"
		return $null
	} else {
		$pathParts = $file.split("/")
		
		# Copy video file to system folder
		Copy-Item -Path "$($launchBoxExportRoot)\$($file)" -Destination "$($outputFolderRoot)\$($systemFolder)\videos\$($pathParts[2])"
			
		return "./videos/$($pathParts[2])"
	}
}

function ConvertDateTime
(
	[string]$dateTime
){
	$date = [DateTime]$dateTime
	
	return $date.toString("yyyyMMdd")
}

###################################################################################

$allXmlFiles = Get-ChildItem "$($launchBoxExportRoot)\Data\Platforms"

ForEach ($xmlFile in $allXmlFiles) {

	ConvertXmlFile $xmlFile.FullName
}
