<?xml version="1.0"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.tei-c.org/ns/1.0" xmlns:xslt="http://www.w3.org/1999/XSL/Transform#nested" xmlns:tei="http://www.tei-c.org/ns/1.0" version="2.0">

  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  
  <!-- translate xslt: elements into xsl: so we can generate xsl from xsl -->
  <xsl:namespace-alias stylesheet-prefix="xslt" result-prefix="xsl"/>
  
  <xsl:template match="/">  
    <xslt:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="tei" version="2.0">
    
      <xslt:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
      
      <xslt:param name="lang">en</xslt:param>
      
      <!-- Needed because we may strip divs -->
      <!-- indent="yes" will re-indent afterwards -->
      <xslt:strip-space elements="tei:body"/>
      
      <!-- ||||||||||||||||||||||||||||||||||||||||||||||| -->
      <!-- |||||||||  copy all existing elements ||||||||| -->
      <!-- ||||||||||||||||||||||||||||||||||||||||||||||| -->
      
      <xslt:template match="@*|node()">
        <xslt:copy>
          <xslt:apply-templates select="@*|node()"/>
        </xslt:copy>
      </xslt:template>
      
      <!-- ||||||||||||||||||||||||||||||||||||||||||||||| -->
      <!-- ||||||||||||||    EXCEPTIONS     |||||||||||||| -->
      <!-- ||||||||||||||||||||||||||||||||||||||||||||||| -->
      
      <!-- Empty <div type='translation'> -->
      <xslt:template match="/tei:TEI/tei:text/tei:body">
        <xslt:copy>
          <xslt:apply-templates select="@*|node()"/>
          <xsl:apply-templates select="element()"/>
        </xslt:copy>
      </xslt:template>
      
      <xslt:template match="tei:div[@type='translation' and @xml:lang=$lang]"/>
    </xslt:stylesheet>
  </xsl:template>
  
  <!-- convert <div type='edition' xml:lang='grc'> to <div type='translation' lang='$lang'> -->
  <xsl:template match="tei:div[@type='edition' and @xml:lang='grc']">
    <div type='translation'>
      <xslt:attribute name="xml:lang"><xslt:value-of select="$lang"/></xslt:attribute>
      <xsl:apply-templates select="node()"/>
    </div>
  </xsl:template>
  
  <!-- copy <div type='textpart'> directly -->
  <xsl:template match="tei:div[@type='textpart']">
    <xsl:element name="div">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="element()"/>
    </xsl:element>
  </xsl:template>
  
  <!-- convert <ab> to <p> and copy all children (lb's) -->
  <xsl:template match="tei:ab">
    <xslt:element name="p">
      <xsl:apply-templates select="element()"/>
    </xslt:element>
  </xsl:template>
  
  <!-- copy <lb> and attributes -->
  <xsl:template match="tei:lb">
    <xsl:element name="lb">
      <xsl:copy-of select="@*"/>
    </xsl:element>
  </xsl:template>
  
  <!-- no text -->
  <xsl:template match="text()"/>
</xsl:stylesheet>
