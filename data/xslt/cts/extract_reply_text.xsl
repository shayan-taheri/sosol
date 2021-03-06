<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
    xmlns:cts="http://chs.harvard.edu/xmlns/cts3"
    xmlns:cts-x="http://alpheios.net/namespaces/cts-x">
    
    <xsl:output method="text"/>
    
    <xsl:template match="/">
        <xsl:apply-templates select="//cts:reply"/>
        <xsl:apply-templates select="//cts-x:reply"/>
    </xsl:template>
    
    <xsl:template match="cts:reply">
        <xsl:copy-of select="node()"/>
    </xsl:template>
    
     <xsl:template match="cts-x:reply">
        <xsl:copy-of select="node()"/>
    </xsl:template>
    
    
    <xsl:template match="*"/>
</xsl:stylesheet>