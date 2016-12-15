param([string]$file='.git\sourcetreeconfig')

# Convert to a (possibly non-existent) absolute path, see
# http://stackoverflow.com/a/3040982/1127485
$fileAbs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)

$regex_InnerXML = git config --global bugtraq.jira.logregex
$linkToUrl_InnerXML = (git config --global bugtraq.jira.url).replace('%BUGID%', '$1')

if (Test-Path $file) {
    Write-Host "Checking existing file '$file' for the LinkType element..."
    $xmlData = [xml](Get-Content $file)
    $linkType = $xmlData.SelectSingleNode('//RepositoryCustomSettings/CommitTextLinks/CommitTextLink/LinkType')

    if ($linkType) {
        Write-Host 'The LinkType element is already present and will not be modified.'
    } else {
        $repoCustomSettings = $xmlData.SelectSingleNode('//RepositoryCustomSettings')
        if ($repoCustomSettings) {
            function GetOrCreateNode($parentNode, $nodeName) {
                $node = $parentNode.SelectSingleNode($nodeName)
                if ($node) {
                    Write-Host "Using existing '$nodeName' node."
                    $node
                } else {
                    Write-Host "Creating new '$nodeName' node."
                    $node = $parentNode.OwnerDocument.CreateElement($nodeName)
                    $parentNode.AppendChild($node)
                }
            }

            $commitTextLinks = GetOrCreateNode $repoCustomSettings 'CommitTextLinks'
            $commitTextLink = GetOrCreateNode $commitTextLinks 'CommitTextLink'

            $linkType = GetOrCreateNode $commitTextLink 'LinkType'
            $linkType.set_InnerXML('Other')

            $regex = GetOrCreateNode $commitTextLink 'Regex'
            $regex.set_InnerXML($regex_InnerXML)

            $linkToUrl = GetOrCreateNode $commitTextLink 'LinkToUrl'
            $linkToUrl.set_InnerXML($linkToUrl_InnerXML)

            $xmlData.Save($fileAbs)
        } else {
            Write-Host "Error: '$file' does not look like a valid SourceTree config file."
        }
    }
} else {
    Write-Host "Creating new file '$file' to add the LinkType element..."

    $xmlData = @"
<?xml version="1.0"?>
<RepositoryCustomSettings xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <CommitTextLinks>
    <CommitTextLink>
      <LinkType>Other</LinkType>
      <Regex>$regex_InnerXML</Regex>
      <LinkToUrl>$linkToUrl_InnerXML</LinkToUrl>
    </CommitTextLink>
  </CommitTextLinks>
</RepositoryCustomSettings>
"@

    # Write the file UTF-8 encoded without BOM.
    [IO.File]::WriteAllLines($fileAbs, $xmlData)
}
