<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:h="http://www.w3.org/1999/xhtml"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="3.0">

<xsl:output method="xml" encoding="utf-8" indent="no"/>

<xsl:mode on-no-match="shallow-copy"/>

<xsl:template match="h:script[contains(@src, 'SaxonJS')]
                     |h:script[ends-with(@src, 'js/start.js')]
                     |h:div[@id='slidesjs_toc']
                     |h:footer
                     |h:aside"/>

<xsl:template match="h:head">
  <xsl:copy>
    <xsl:apply-templates select="@*,node()"/>
    <link rel="stylesheet" href="css/print.css" media="print"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="h:main">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="h:main/h:header">
  <div class="slide titlepage" id="{generate-id(.)}">
    <xsl:apply-templates/>
  </div>
  <div class="slide toc">
    <header>
      <h1>Table of Contents</h1>
    </header>
    <div>
      <xsl:apply-templates select="/h:html/h:body/h:main" mode="toc"/>
    </div>
  </div>
</xsl:template>

<xsl:template match="h:main/h:section">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="h:main/h:section/h:header">
  <div class="slide sectiontitle" id="{generate-id(.)}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="h:div[contains-token(@class, 'slide')]">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:attribute name="id" select="generate-id(h:header)"/>
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="h:h3[contains-token(@class, 'date')]">
  <xsl:variable name="date" select="normalize-space(.)"/>

  <h3>
    <xsl:sequence select="@*"/>
    <xsl:choose>
      <xsl:when test="empty(*) and $date castable as xs:dateTime">
        <xsl:sequence
            select="format-dateTime(xs:dateTime($date), '[D1] [MNn,*-3] [Y0001]')"/>
      </xsl:when>
      <xsl:when test="empty(*) and $date castable as xs:date">
        <xsl:sequence select="format-date(xs:date($date), '[D1] [MNn,*-3] [Y0001]')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$date"/>
      </xsl:otherwise>
    </xsl:choose>
  </h3>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="h:main" mode="toc">
  <ul>
    <xsl:apply-templates select="h:section|h:div"
                         mode="toc"/>
  </ul>
</xsl:template>

<xsl:template match="h:section" mode="toc">
  <xsl:variable name="slideno"
                select="count(preceding::h:div[contains-token(@class, 'slide')])
                        + count(preceding::h:section)
                        + 1"/>
  <li>
    <span>
      <a href="#{generate-id(h:header)}">
        <xsl:apply-templates select="h:header/h:h1/node()"/>
      </a>
    </span>
    <xsl:where-populated>
      <ul>
        <xsl:apply-templates select="h:div" mode="toc"/>
      </ul>
    </xsl:where-populated>
  </li>
</xsl:template>

<xsl:template match="h:div" mode="toc">
  <xsl:variable name="slideno"
                select="count(preceding::h:div[contains-token(@class, 'slide')])
                        + count(preceding::h:section)
                        + count(ancestor::h:section)
                        + 1"/>
  <li>
    <span>
      <a href="#{generate-id(h:header)}">
        <xsl:apply-templates select="h:header/h:h1/node()"/>
      </a>
    </span>
  </li>
</xsl:template>

<!-- ============================================================ -->

</xsl:stylesheet>
