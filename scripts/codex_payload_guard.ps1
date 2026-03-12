param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputPath = "",

    [int]$KeepLastDialogMessages = 120,

    [int]$ToolMaxChars = 1200,

    [bool]$DropAltRepresentation = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Has-Prop {
    param(
        [object]$Obj,
        [string]$Name
    )
    if ($null -eq $Obj) { return $false }
    return ($Obj.PSObject.Properties.Name -contains $Name)
}

function Get-CanonicalPath {
    param([object]$Payload)
    if ($null -ne $Payload.extra_body -and $null -ne $Payload.extra_body.messages) {
        return "extra_body.messages"
    }
    if ($null -ne $Payload.messages) {
        return "messages"
    }
    throw "Cannot find messages array in payload."
}

function Get-TextLength {
    param([object]$Message)
    $len = 0
    if ($null -eq $Message) { return 0 }

    if ($null -ne $Message.content) {
        if ($Message.content -is [string]) {
            return $Message.content.Length
        }
        if ($Message.content -is [System.Array]) {
            foreach ($chunk in $Message.content) {
                if ($null -eq $chunk) { continue }
                if ((Has-Prop -Obj $chunk -Name "text") -and $null -ne $chunk.text) {
                    $len += ([string]$chunk.text).Length
                }
                if ((Has-Prop -Obj $chunk -Name "image_url") -and $null -ne $chunk.image_url -and (Has-Prop -Obj $chunk.image_url -Name "url") -and $null -ne $chunk.image_url.url) {
                    $len += ([string]$chunk.image_url.url).Length
                }
            }
            return $len
        }
        if ((Has-Prop -Obj $Message.content -Name "multiple_content") -and $null -ne $Message.content.multiple_content) {
            foreach ($chunk in $Message.content.multiple_content) {
                if ($null -eq $chunk) { continue }
                if ((Has-Prop -Obj $chunk -Name "text") -and $null -ne $chunk.text) {
                    $len += ([string]$chunk.text).Length
                }
                if ((Has-Prop -Obj $chunk -Name "image_url") -and $null -ne $chunk.image_url -and (Has-Prop -Obj $chunk.image_url -Name "url") -and $null -ne $chunk.image_url.url) {
                    $len += ([string]$chunk.image_url.url).Length
                }
            }
            return $len
        }
    }
    return 0
}

function Get-Metrics {
    param(
        [object]$Payload,
        [string]$CanonicalPath
    )

    $messages = @()
    if ($CanonicalPath -eq "extra_body.messages") {
        $messages = @($Payload.extra_body.messages)
    } else {
        $messages = @($Payload.messages)
    }

    $textChars = 0
    foreach ($m in $messages) {
        $textChars += (Get-TextLength -Message $m)
    }

    $canonicalJson = ($messages | ConvertTo-Json -Depth 100 -Compress)
    $payloadJson = ($Payload | ConvertTo-Json -Depth 100 -Compress)

    return [pscustomobject]@{
        CanonicalPath         = $CanonicalPath
        MessageCount          = $messages.Count
        TextChars             = $textChars
        TextApproxTokens      = [math]::Round($textChars / 4)
        CanonicalJsonChars    = $canonicalJson.Length
        CanonicalApproxTokens = [math]::Round($canonicalJson.Length / 4)
        PayloadJsonChars      = $payloadJson.Length
        PayloadApproxTokens   = [math]::Round($payloadJson.Length / 4)
    }
}

function Truncate-ToolOutput {
    param(
        [string]$Text,
        [int]$MaxChars
    )
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ($Text.Length -le $MaxChars) { return $Text }

    $head = [math]::Floor($MaxChars * 0.65)
    $tail = $MaxChars - $head
    return ($Text.Substring(0, $head) + "`n... [truncated by payload guard] ...`n" + $Text.Substring($Text.Length - $tail))
}

function Sanitize-Messages {
    param(
        [System.Collections.ArrayList]$Messages,
        [int]$KeepLastDialogMessages,
        [int]$ToolMaxChars
    )

    $metaSeen = @{}
    $filtered = New-Object System.Collections.ArrayList

    for ($i = 0; $i -lt $Messages.Count; $i++) {
        $msg = $Messages[$i] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        $role = [string]$msg.role

        # Extract plain text for rule matching
        $flatText = ""
        if ($msg.content -is [string]) {
            $flatText = $msg.content
        } elseif ($msg.content -is [System.Array]) {
            $parts = @()
            foreach ($chunk in $msg.content) {
                if ((Has-Prop -Obj $chunk -Name "text") -and $null -ne $chunk.text) { $parts += [string]$chunk.text }
                if ((Has-Prop -Obj $chunk -Name "image_url") -and $null -ne $chunk.image_url -and (Has-Prop -Obj $chunk.image_url -Name "url") -and $null -ne $chunk.image_url.url) { $parts += [string]$chunk.image_url.url }
            }
            $flatText = ($parts -join " ")
        } elseif ((Has-Prop -Obj $msg.content -Name "multiple_content") -and $null -ne $msg.content.multiple_content) {
            $parts = @()
            foreach ($chunk in $msg.content.multiple_content) {
                if ((Has-Prop -Obj $chunk -Name "text") -and $null -ne $chunk.text) { $parts += [string]$chunk.text }
                if ((Has-Prop -Obj $chunk -Name "image_url") -and $null -ne $chunk.image_url -and (Has-Prop -Obj $chunk.image_url -Name "url") -and $null -ne $chunk.image_url.url) { $parts += [string]$chunk.image_url.url }
            }
            $flatText = ($parts -join " ")
        }

        # Drop internal encrypted payload and internal action payload from user messages.
        if ($role -eq "user" -and $flatText -match '^\{"content":null,"encrypted_content"') {
            continue
        }
        if ($role -eq "user" -and $flatText -match '^\{"action":') {
            continue
        }

        # Deduplicate giant meta/system instruction blocks after first occurrence.
        if (($role -eq "developer" -or $role -eq "system") -and ($flatText -match '<permissions instructions>|<app-context>|<personality_spec>|# AGENTS\.md instructions|You are Codex, a coding agent')) {
            if ($metaSeen.ContainsKey($flatText)) {
                continue
            }
            $metaSeen[$flatText] = $true
        }

        # Truncate very long tool output strings.
        if ($role -eq "tool" -and $msg.content -is [string]) {
            $msg.content = (Truncate-ToolOutput -Text $msg.content -MaxChars $ToolMaxChars)
        }

        # Remove inline base64 image data from content arrays.
        if ($msg.content -is [System.Array]) {
            $newChunks = New-Object System.Collections.ArrayList
            foreach ($chunk in $msg.content) {
                if ((Has-Prop -Obj $chunk -Name "image_url") -and $null -ne $chunk.image_url -and (Has-Prop -Obj $chunk.image_url -Name "url") -and $null -ne $chunk.image_url.url -and ([string]$chunk.image_url.url).StartsWith("data:image/")) {
                    $bytesLen = ([string]$chunk.image_url.url).Length
                    $replacement = [pscustomobject]@{
                        type = "text"
                        text = "[image omitted by payload guard; inline data url length=$bytesLen]"
                    }
                    [void]$newChunks.Add($replacement)
                } else {
                    [void]$newChunks.Add($chunk)
                }
            }
            $msg.content = @($newChunks)
        }

        [void]$filtered.Add($msg)
    }

    # Keep all system/developer messages and only last N dialog messages.
    $dialogIdx = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $r = [string]$filtered[$i].role
        if ($r -ne "system" -and $r -ne "developer") {
            [void]$dialogIdx.Add($i)
        }
    }

    $keepDialogSet = @{}
    $start = [math]::Max(0, $dialogIdx.Count - $KeepLastDialogMessages)
    for ($j = $start; $j -lt $dialogIdx.Count; $j++) {
        $keepDialogSet[[int]$dialogIdx[$j]] = $true
    }

    $final = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $r = [string]$filtered[$i].role
        if ($r -eq "system" -or $r -eq "developer" -or $keepDialogSet.ContainsKey($i)) {
            [void]$final.Add($filtered[$i])
        }
    }

    return @($final)
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$raw = Get-Content -LiteralPath $resolvedInput -Raw
$payload = $raw | ConvertFrom-Json -Depth 100

$canonicalBefore = Get-CanonicalPath -Payload $payload
$before = Get-Metrics -Payload $payload -CanonicalPath $canonicalBefore

$messagesToSanitize = @()
if ($canonicalBefore -eq "extra_body.messages") {
    $messagesToSanitize = New-Object System.Collections.ArrayList
    foreach ($m in @($payload.extra_body.messages)) { [void]$messagesToSanitize.Add($m) }
} else {
    $messagesToSanitize = New-Object System.Collections.ArrayList
    foreach ($m in @($payload.messages)) { [void]$messagesToSanitize.Add($m) }
}

$sanitized = Sanitize-Messages -Messages $messagesToSanitize -KeepLastDialogMessages $KeepLastDialogMessages -ToolMaxChars $ToolMaxChars

if ($canonicalBefore -eq "extra_body.messages") {
    $payload.extra_body.messages = @($sanitized)
    if ($DropAltRepresentation -and $null -ne $payload.messages) {
        $payload.messages = @()
    }
} else {
    $payload.messages = @($sanitized)
    if ($DropAltRepresentation -and $null -ne $payload.extra_body -and $null -ne $payload.extra_body.messages) {
        $payload.extra_body.messages = @()
    }
}

$canonicalAfter = Get-CanonicalPath -Payload $payload
$after = Get-Metrics -Payload $payload -CanonicalPath $canonicalAfter

$summary = [pscustomobject]@{
    InputPath                      = $resolvedInput
    CanonicalPathBefore            = $before.CanonicalPath
    CanonicalPathAfter             = $after.CanonicalPath
    MessageCountBefore             = $before.MessageCount
    MessageCountAfter              = $after.MessageCount
    TextCharsBefore                = $before.TextChars
    TextCharsAfter                 = $after.TextChars
    TextCharsSaved                 = ($before.TextChars - $after.TextChars)
    TextReductionPct               = [math]::Round((($before.TextChars - $after.TextChars) / [math]::Max(1, $before.TextChars)) * 100, 2)
    CanonicalJsonCharsBefore       = $before.CanonicalJsonChars
    CanonicalJsonCharsAfter        = $after.CanonicalJsonChars
    CanonicalJsonSaved             = ($before.CanonicalJsonChars - $after.CanonicalJsonChars)
    CanonicalReductionPct          = [math]::Round((($before.CanonicalJsonChars - $after.CanonicalJsonChars) / [math]::Max(1, $before.CanonicalJsonChars)) * 100, 2)
    PayloadJsonCharsBefore         = $before.PayloadJsonChars
    PayloadJsonCharsAfter          = $after.PayloadJsonChars
    PayloadJsonSaved               = ($before.PayloadJsonChars - $after.PayloadJsonChars)
    PayloadReductionPct            = [math]::Round((($before.PayloadJsonChars - $after.PayloadJsonChars) / [math]::Max(1, $before.PayloadJsonChars)) * 100, 2)
    KeepLastDialogMessages         = $KeepLastDialogMessages
    ToolMaxChars                   = $ToolMaxChars
    DropAltRepresentationApplied   = $DropAltRepresentation
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    ($payload | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $summary | Add-Member -NotePropertyName OutputPath -NotePropertyValue (Resolve-Path -LiteralPath $OutputPath).Path
}

$summary
