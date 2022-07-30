<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 	        xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
                xmlns:f="https://nwalsh.com/ns/org-to-xml/functions"
                xmlns:h="http://www.w3.org/1999/xhtml"
                xmlns:js="http://saxonica.com/ns/globalJS"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:saxon="http://saxon.sf.net/"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="3.0">

<xsl:output method="html" html-version="5" encoding="utf-8" indent="no"/>

<xsl:mode on-no-match="shallow-copy"/>

<xsl:variable name="seropt" select="map{'method':'xml','indent':true()}"/>
<xsl:variable name="ZERO-SECONDS" select="xs:dayTimeDuration('PT0S')"/>
<xsl:variable name="ONE-MINUTE" select="xs:dayTimeDuration('PT1M')"/>
<xsl:variable name="FIVE-MINUTES" select="xs:dayTimeDuration('PT5M')"/>
<xsl:variable name="TEN-MINUTES" select="xs:dayTimeDuration('PT10M')"/>

<xsl:variable name="update-interval" select="50"/>

<xsl:variable name="slides" select="/"/>
<xsl:variable name="last-slideno"
              select="count(//h:section) + count(//h:div[contains-token(@class, 'slide')])"/>

<xsl:variable name="errors" as="xs:string*">
  <xsl:apply-templates select="/h:html" mode="errors"/>
</xsl:variable>

<xsl:variable name="countdown-timer"
              select="(/html/head/meta[@name='timer'])[1]/@content/string()
                      = ('yes', 'true', '1')"/>
<xsl:variable name="meta-length"
              select="(/html/head/meta[@name='talk-length'])[1]/@content/string()"/>
<xsl:variable name="talk-minutes"
              select="if (empty($meta-length))
                      then 0
                      else if (contains($meta-length, ':'))
                           then 60 * xs:integer(substring-before($meta-length, ':'))
                                + xs:integer(substring-after($meta-length, ':'))
                           else xs:integer($meta-length)"/>
<xsl:variable name="talk-duration"
              select="xs:dayTimeDuration('PT' || $talk-minutes || 'M')"/>

<xsl:variable name="localStorageKey"
              select="ixsl:page()/html/head/meta[@name='localStorage.key']/@content/string()"/>

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="exists($errors)">
      <xsl:result-document href="#slidesjs_main" method="ixsl:replace-content">
        <p>Input HTML document has errors:</p>
        <ul>
          <xsl:for-each select="$errors">
            <li><xsl:sequence select="."/></li>
          </xsl:for-each>
        </ul>
      </xsl:result-document>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="render-slide">
        <xsl:with-param name="slideno" select="f:slideno()"/>
      </xsl:call-template>
      <ixsl:schedule-action wait="$update-interval">
        <xsl:call-template name="updateSpeakerNotes"/>
      </ixsl:schedule-action>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:result-document href="#slidesjs_toc" method="ixsl:replace-content">
    <header>
      <h1>Table of Contents</h1>
    </header>
    <div>
      <xsl:apply-templates select="/html/body/main" mode="toc"/>
    </div>
  </xsl:result-document>

  <xsl:result-document href="#slidesjs_nav" method="ixsl:replace-content">
    <a href="https://github.com/ndw">help?</a>
    <xsl:text> </xsl:text>
    <span class="link" x-slide="toc">contents?</span>
    <xsl:text> </xsl:text>
    <span class="link" x-slide="0">restart?</span>
  </xsl:result-document>

  <xsl:if test="$countdown-timer or $talk-duration gt $ZERO-SECONDS">
    <xsl:call-template name="updateTime"/>
    <xsl:result-document href="#slidesjs_time_reset" method="ixsl:replace-content">
      <xsl:text>reset</xsl:text>
    </xsl:result-document>
  </xsl:if>

  <xsl:result-document href="#slidesjs_copyright" method="ixsl:replace-content">
    <xsl:sequence select="/html/body/main/header/div[contains-token(@class, 'copyright')]/node()"/>
  </xsl:result-document>
</xsl:template>

<xsl:template name="updateSpeakerNotes">
  <xsl:variable name="navigated" select="f:get-property('navigated')"/>
  <xsl:variable name="currentPage" select="f:get-property('currentPage')"/>
  <xsl:variable name="reload" select="f:get-property('reload')"/>
  <xsl:variable name="revealed" select="f:get-property('reveal')"/>
  <xsl:variable name="unrevealed" select="f:get-property('unreveal')"/>

  <xsl:variable name="curloc"
                select="ixsl:get(ixsl:window(), 'location.href')"/>

  <xsl:if test="not($navigated)">
    <xsl:choose>
      <xsl:when test="$currentPage != '' and $currentPage != $curloc">
        <xsl:call-template name="render-slide">
          <xsl:with-param name="slideno"
                          select="f:slideno($currentPage)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$reload != ''">
        <xsl:call-template name="render-slide">
          <xsl:with-param name="slideno"
                          select="f:slideno($curloc)"/>
        </xsl:call-template>
        <xsl:sequence select="f:set-property('reload', '')"/>
      </xsl:when>
      <xsl:otherwise>
      </xsl:otherwise>
    </xsl:choose>
    
    <xsl:if test="$revealed">
      <xsl:variable name="element" select="id($revealed, ixsl:page())"/>
      <ixsl:set-attribute name="class"
                          select="'revealed'"
                          object="$element"/>
      <xsl:sequence select="f:store('reveal', '')"/>
      <xsl:sequence select="f:set-property('reveal', false())"/>
    </xsl:if>    

    <xsl:if test="$unrevealed">
      <xsl:variable name="element" select="id($unrevealed, ixsl:page())"/>
      <ixsl:set-attribute name="class"
                          select="'unrevealed'"
                          object="$element"/>
      <xsl:sequence select="f:store('unreveal', '')"/>
      <xsl:sequence select="f:set-property('unreveal', false())"/>
    </xsl:if>    
  </xsl:if>

  <xsl:sequence select="f:set-property('navigated', false())"/>

  <ixsl:schedule-action wait="$update-interval">
    <xsl:call-template name="updateSpeakerNotes"/>
  </ixsl:schedule-action>
</xsl:template>

<xsl:template name="updateTime">
  <xsl:param name="once" as="xs:boolean" select="false()"/>

  <xsl:variable name="paused" select="f:get-property('paused')"/>
  <xsl:variable name="start" select="xs:dateTime(f:get-property('startTime'))"/>
  <xsl:variable name="savedDuration" select="xs:dayTimeDuration(f:get-property('duration'))"/>

  <xsl:variable name="duration" as="xs:dayTimeDuration">
    <xsl:choose>
      <xsl:when test="$paused">
        <xsl:sequence select="xs:dayTimeDuration('PT0S')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="f:rounded-duration(saxon:timestamp() - $start)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="displayDuration" select="f:rounded-duration($savedDuration + $duration)"/>

  <xsl:result-document href="#slidesjs_time" method="ixsl:replace-content">
    <xsl:if test="$countdown-timer">
      <span id="slidesjs_pause">
        <xsl:choose>
          <xsl:when test="$paused">
            <xsl:attribute name="class" select="'slidesjs_paused'"/>
            <xsl:text>⏵ </xsl:text>
            <xsl:sequence select="f:format-duration($displayDuration, true())"/>
            <xsl:if test="$paused"> PAUSED</xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>⏸ </xsl:text>
            <xsl:sequence select="f:format-duration($displayDuration, true())"/>
          </xsl:otherwise>
        </xsl:choose>
      </span>
    </xsl:if>
    <xsl:if test="$talk-duration gt $ZERO-SECONDS">
      <xsl:text>/</xsl:text>
      <xsl:variable name="remaining"
                    select="f:rounded-duration($talk-duration - $displayDuration)"/>
      <span>
        <xsl:attribute name="class">
          <xsl:choose>
            <xsl:when test="$remaining lt $ZERO-SECONDS">warning-overrun</xsl:when>
            <xsl:when test="$remaining lt $ONE-MINUTE
                            and seconds-from-duration($remaining) mod 2 = 0">warning-red</xsl:when>
            <xsl:when test="$remaining lt $ONE-MINUTE">warning-orange</xsl:when>
            <xsl:when test="$remaining lt $FIVE-MINUTES">warning-orange</xsl:when>
            <xsl:when test="$remaining lt $TEN-MINUTES">warning-yellow</xsl:when>
            <xsl:otherwise>remaining</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:sequence select="f:format-duration($remaining)"/>
      </span>
    </xsl:if>
  </xsl:result-document>

  <xsl:result-document href="#slidesjs_message" method="ixsl:replace-content">
    <xsl:if test="ixsl:page()//h:li[contains-token(@class, 'unrevealed')]">
      <xsl:text>(progressive)</xsl:text>
    </xsl:if>
  </xsl:result-document>

  <xsl:if test="not($once)">
    <xsl:sequence select="f:store('paused', string($paused))"/>
    <ixsl:schedule-action wait="1000">
      <xsl:call-template name="updateTime"/>
    </ixsl:schedule-action>
  </xsl:if>
</xsl:template>

<xsl:template name="navigate-to">
  <xsl:param name="slideno" as="xs:integer"/>
  
  <xsl:call-template name="render-slide">
    <xsl:with-param name="slideno" select="$slideno"/>
  </xsl:call-template>

  <xsl:if test="$localStorageKey">
    <xsl:variable name="curloc"
                  select="ixsl:get(ixsl:window(), 'location.href')"/>
    <xsl:variable name="storeloc"
                  select="ixsl:call(ixsl:window(), 'localStorage.getItem',
                                    [$localStorageKey || '.currentPage'])"/>
    <xsl:if test="$curloc != $storeloc">
      <xsl:sequence select="f:store('currentPage', $curloc)"/>
    </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template name="render-slide">
  <xsl:param name="slideno" as="xs:integer"/>

  <ixsl:set-property name="location.hash"
                     select="if ($slideno = 0) then '' else $slideno"/>

  <xsl:variable name="slide" select="f:slide($slideno)"/>

  <xsl:variable name="classes" as="xs:string+">
    <xsl:choose>
      <xsl:when test="$slideno = 0">titlepage</xsl:when>
      <xsl:when test="$slide/self::h:section">section</xsl:when>
      <xsl:otherwise>slide</xsl:otherwise>
    </xsl:choose>
    <xsl:if test="f:get-property('showNotes')">notespage</xsl:if>
  </xsl:variable>

  <xsl:variable name="toc-div" select="(ixsl:page()//h:div[@id = 'slidesjs_toc'])[1]"/>
  <ixsl:set-attribute name="class" object="$toc-div" select="'hidden'"/>
  
  <ixsl:set-attribute name="class"
                      select="string-join($classes, ' ')"
                      object="ixsl:page()/html/body"/>

  <xsl:result-document href="#slidesjs_main" method="ixsl:replace-content">
    <xsl:apply-templates select="f:slide($slideno)"/>
  </xsl:result-document>

  <xsl:result-document href="#slidesjs_pageno" method="ixsl:replace-content">
    <xsl:sequence select="$slideno || ' of ' || $last-slideno"/>
  </xsl:result-document>

  <xsl:sequence select="ixsl:call(ixsl:window(), 'forceHighlight', array{})"/>
  <xsl:sequence select="f:set-property('currentPage', ixsl:get(ixsl:window(), 'location.href'))"/>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="h:main/h:header|h:section|h:div[contains-token(@class, 'slide')]"
              priority="100"> 
  <div>
    <div class="{if (f:get-property('showNotes')) then 'slidenotes' else 'slide'}">
      <xsl:next-match/>
    </div>
    <xsl:apply-templates select="h:aside" mode="notes"/>
  </div>
</xsl:template>

<!-- the title slide -->
<xsl:template match="h:header"> 
  <header>
    <xsl:apply-templates select="h1, h2"/>
    <xsl:apply-templates select="h3[contains-token(@class, 'date')]"/>
    <xsl:choose>
      <xsl:when test="count(h3[contains-token(@class, 'author')]) gt 1">
        <div class="authorgroup">
          <xsl:apply-templates select="h3[contains-token(@class, 'author')]"/>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="h3[contains-token(@class, 'author')]"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="h3[contains-token(@class, 'conference')]"/>
  </header>
</xsl:template>

<!-- section title slide -->
<xsl:template match="h:section"> 
  <xsl:apply-templates select="h:header"/>
</xsl:template>

<!-- an ordinary slide -->
<xsl:template match="h:div[contains-token(@class, 'slide')]"> 
  <xsl:apply-templates select="node() except h:aside"/>
</xsl:template>

<xsl:template match="h3[contains-token(@class, 'date')]">
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

<xsl:template match="li">
  <xsl:variable name="progressive"
                select="ancestor::ul[contains-token(@class, 'progressive')]
                        or ancestor::ul[contains-token(@class, 'progressive')]"/>
  <li>
    <xsl:sequence select="@* except @class"/>
    <xsl:if test="not(@id)">
      <xsl:attribute name="id" select="f:tumble-id(.)"/>
    </xsl:if>
    <xsl:if test="$progressive and preceding-sibling::li || ancestor::li">
      <xsl:attribute name="class" select="'unrevealed ' || @class"/>
    </xsl:if>
    <xsl:apply-templates/>
  </li>
</xsl:template>

<xsl:template match="h:aside" mode="notes">
  <div class="{if (f:get-property('showNotes')) then 'shownotes' else 'speakernotes'}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="html" mode="ixsl:onkeyup">
  <xsl:variable name="key" select="ixsl:get(ixsl:event(), 'key')"/>
  <xsl:variable name="slideno" select="f:slideno()"/>

  <!-- The keypress happened in this browser -->
  <ixsl:set-property name="manageSpeakerNotes.navigated"
                     select="true()"/>

  <xsl:variable name="hidden"
                select="ixsl:page()//*[contains-token(@class, 'unrevealed')]"/>
  <xsl:variable name="revealed"
                select="ixsl:page()//*[contains-token(@class, 'revealed')]"/>

  <xsl:choose>
    <xsl:when test="$key = 'n' and $slideno lt $last-slideno">
      <xsl:call-template name="navigate-to">
        <xsl:with-param name="slideno" select="$slideno + 1"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="($key = ' ' or $key = 'ArrowRight' or $key = 'ArrowDown') and $hidden">
      <ixsl:set-attribute name="class"
                          select="'revealed'"
                          object="$hidden[1]"/>
      <xsl:if test="$localStorageKey">
        <xsl:sequence select="f:store('reveal', $hidden[1]/@id)"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="($key = ' ' or $key = 'ArrowRight' or $key = 'ArrowDown')
                    and $slideno lt $last-slideno">
      <xsl:call-template name="navigate-to">
        <xsl:with-param name="slideno" select="$slideno + 1"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$key = 'p' and $slideno gt 0">
      <xsl:call-template name="navigate-to">
        <xsl:with-param name="slideno" select="$slideno - 1"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="($key = 'ArrowLeft' or $key = 'ArrowUp') and $revealed">
      <ixsl:set-attribute name="class"
                          select="'unrevealed'"
                          object="$revealed[last()]"/>
      <xsl:if test="$localStorageKey">
        <xsl:sequence select="f:store('unreveal', $revealed[last()]/@id)"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="($key = 'ArrowLeft' or $key = 'ArrowUp')
                    and $slideno gt 0">
      <xsl:call-template name="navigate-to">
        <xsl:with-param name="slideno" select="$slideno - 1"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$key = 'h'">
      <xsl:call-template name="navigate-to">
        <xsl:with-param name="slideno" select="0"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$key = 'a' and $hidden">
      <xsl:for-each select="$hidden">
        <ixsl:set-attribute name="class"
                            select="'revealed'"
                            object="."/>
      </xsl:for-each>
    </xsl:when>
    <xsl:when test="$key = 's'">
      <xsl:sequence select="f:set-property('showNotes', not(f:get-property('showNotes')))"/>
      <xsl:call-template name="render-slide">
        <xsl:with-param name="slideno" select="f:slideno()"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$key = 't'">
      <xsl:variable name="toc-div" select="(ixsl:page()//h:div[@id = 'slidesjs_toc'])[1]"/>
      <ixsl:set-attribute name="class" object="$toc-div"
                          select="if (contains-token($toc-div/@class, 'hidden'))
                                  then 'block'
                                  else 'hidden'"/>
    </xsl:when>
    <xsl:when test="$key = 'Escape'">
      <xsl:variable name="toc-div" select="(ixsl:page()//h:div[@id = 'slidesjs_toc'])[1]"/>
      <ixsl:set-attribute name="class" object="$toc-div" select="'hidden'"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message select="'Unexpected key ' || $key || ' on '
        || $slideno || ' of ' || $last-slideno"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="h:span[@id='slidesjs_pause']" mode="ixsl:onclick">
  <xsl:choose>
    <xsl:when test="f:get-property('paused')">
      <ixsl:set-attribute name="class" select="'slidesjs_running'" object="."/>
      <xsl:variable name="now" select="string(saxon:timestamp())"/>
      <xsl:sequence select="f:store('startTime', $now)"/>
      <xsl:sequence select="f:store('paused', 'false')"/>
      <xsl:sequence select="f:set-property('startTime', $now)"/>
      <xsl:sequence select="f:set-property('paused', false())"/>
    </xsl:when>
    <xsl:otherwise>
      <ixsl:set-attribute name="class" select="'slidesjs_paused'" object="."/>
      <xsl:variable name="now" select="saxon:timestamp()"/>
      <xsl:variable name="then" select="xs:dateTime(f:get-property('startTime'))"/>

      <xsl:variable name="total"
                    select="f:rounded-duration(xs:dayTimeDuration(f:get-property('duration'))
                                               + ($now - $then))"/>

      <xsl:sequence select="f:store('duration', string($total))"/>
      <xsl:sequence select="f:store('paused', 'true')"/>
      <xsl:sequence select="f:set-property('duration', string($total))"/>
      <xsl:sequence select="f:set-property('paused', true())"/>
    </xsl:otherwise>
  </xsl:choose>

  <xsl:call-template name="updateTime">
    <xsl:with-param name="once" select="true()"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="h:span[@id='slidesjs_time_reset']" mode="ixsl:onclick">
  <xsl:sequence select="f:set-property('paused', true())"/>
  <xsl:sequence select="f:set-property('duration', 'PT0S')"/>
  <xsl:sequence select="f:store('paused', 'true')"/>
  <xsl:sequence select="f:store('duration', 'PT0S')"/>
  <xsl:call-template name="updateTime">
    <xsl:with-param name="once" select="true()"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="h:span[contains-token(@class, 'link')]" mode="ixsl:onclick">
  <xsl:choose>
    <xsl:when test="@x-slide castable as xs:integer">
      <xsl:call-template name="render-slide">
        <xsl:with-param name="slideno" select="xs:integer(@x-slide)"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@x-slide = 'toc'">
      <xsl:variable name="toc-div" select="(ixsl:page()//h:div[@id = 'slidesjs_toc'])[1]"/>
      <ixsl:set-attribute name="class" object="$toc-div"
                          select="if (contains-token($toc-div/@class, 'hidden'))
                                  then 'block'
                                  else 'hidden'"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message select="'Unexpected link to ' || @x-slide"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="h:main" mode="toc">
  <ul>
    <li>
      <span class="link" x-slide="0">
        <xsl:apply-templates select="/h:html/h:body/h:main/h:header/h:h1/node()"/>
      </span>
    </li>
    <xsl:apply-templates select="h:section|h:div" mode="toc"/>
  </ul>
</xsl:template>

<xsl:template match="h:section" mode="toc">
  <xsl:variable name="slideno"
                select="count(preceding::h:div[contains-token(@class, 'slide')])
                        + count(preceding::h:section)
                        + 1"/>
  <li>
    <span>
      <span class="link" x-slide="{$slideno}">
        <xsl:apply-templates select="h:header/h:h1/node()"/>
      </span>
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
      <span class="link" x-slide="{$slideno}">
        <xsl:apply-templates select="h:header/h:h1/node()"/>
      </span>
    </span>
  </li>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="h:html" mode="errors" as="xs:string*">
  <xsl:if test="not(h:body)">body expected</xsl:if>
  <xsl:apply-templates select="h:body" mode="errors"/>
</xsl:template>

<xsl:template match="h:body" mode="errors" as="xs:string*">
  <xsl:variable name="main" select="h:main[@id='slidesjs_main']"/>
  <xsl:variable name="toc" select="h:div[@id='slidesjs_toc']"/>
  <xsl:variable name="notes_footer"
                select="h:footer[contains-token(@class, 'slidesjs_notes_footer')]"/>
  <xsl:variable name="slides_footer" select="h:footer except $notes_footer"/>
  <xsl:variable name="scripts" select="h:script"/>
  <xsl:variable name="extra"
                select="* except ($main|$toc|$notes_footer|$slides_footer|$scripts)"/>

  <xsl:if test="count($main) ne 1">Exactly one main element expected</xsl:if>
  <xsl:if test="count($toc) ne 1">Exactly one ToC div expected</xsl:if>
  <xsl:if test="count($notes_footer) ne 1">Exactly one speakernotes footer expected</xsl:if>
  <xsl:if test="count($slides_footer) ne 1">Exactly one slides footer expected</xsl:if>
  <xsl:for-each select="$extra">
    <xsl:sequence select="'Unexpected extra ' || local-name(.)"/>
  </xsl:for-each>
  <xsl:apply-templates select="$main" mode="errors"/>
</xsl:template>

<xsl:template match="h:main" mode="errors" as="xs:string*">
  <xsl:variable name="header" select="h:header"/>
  <xsl:variable name="slides" select="h:div[contains-token(@class, 'slide')]"/>
  <xsl:variable name="sections" select="h:section"/>
  <xsl:variable name="extra" select="* except ($header|$slides|$sections)"/>

  <xsl:if test="count($header) ne 1">Exactly one main header expected</xsl:if>
  <xsl:for-each select="$extra">
    <xsl:sequence select="'Unexpected extra ' || local-name(.) || ' in main'"/>
  </xsl:for-each>
  <xsl:apply-templates select="$slides|$sections" mode="errors"/>
</xsl:template>

<xsl:template match="h:section" mode="errors" as="xs:string*">
  <xsl:variable name="header" select="h:header"/>
  <xsl:variable name="slides" select="h:div[contains-token(@class, 'slide')]"/>
  <xsl:variable name="extra" select="* except ($header|$slides)"/>

  <xsl:if test="count($header) ne 1">Exactly one section header expected</xsl:if>
  <xsl:for-each select="$extra">
    <xsl:sequence select="'Unexpected extra ' || local-name(.) || ' in section'"/>
  </xsl:for-each>
  <xsl:apply-templates select="$slides" mode="errors"/>
</xsl:template>

<xsl:template match="h:div" mode="errors" as="xs:string*">
  <xsl:variable name="header" select="h:header"/>
  <xsl:variable name="slides" select=".//h:div[contains-token(@class, 'slide')]"/>

  <xsl:if test="count($header) ne 1">Exactly one slide header expected</xsl:if>
  <xsl:if test="exists($slides)">Unexpected nested slides</xsl:if>
</xsl:template>

<!-- ============================================================ -->

<xsl:function name="f:slideno" as="xs:integer">
  <xsl:sequence select="f:slideno(ixsl:get(ixsl:window(), 'location.hash'))"/>
</xsl:function>

<xsl:function name="f:slideno" as="xs:integer">
  <xsl:param name="hash" as="xs:string"/>

  <xsl:sequence select="if (substring-after($hash, '#') castable as xs:integer)
                        then xs:integer(substring-after($hash, '#'))
                        else 0"/>
</xsl:function>

<xsl:function name="f:slide" as="element()">
  <xsl:param name="slideno" as="xs:integer"/>

  <xsl:variable name="main" select="$slides/html/body/main"/>

  <xsl:choose>
    <xsl:when test="$slideno = 0">
      <xsl:sequence select="$main/header"/>
    </xsl:when>
    <xsl:when test="$slideno le $last-slideno">
      <xsl:sequence select="($main/div[contains-token(@class, 'slide')]
                             | $main/section
                             | $main/section/div[contains-token(@class, 'slide')])[$slideno]"/>
    </xsl:when>
    <xsl:otherwise>
      <div>
        <xsl:text>Unable to render slide </xsl:text>
        <xsl:sequence select="$slideno"/>
        <xsl:text> of </xsl:text>
        <xsl:sequence select="$last-slideno"/>
        <xsl:text>.</xsl:text>
      </div>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>

<xsl:function name="f:rounded-duration" as="xs:dayTimeDuration">
  <xsl:param name="duration" as="xs:dayTimeDuration"/>

  <!-- get rid of the fractional seconds -->
  <xsl:variable name="sd" select="string($duration)"/>
  <xsl:choose>
    <xsl:when test="contains($sd, '.')">
      <xsl:sequence select="xs:dayTimeDuration(substring-before($sd, '.')||'S')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:sequence select="$duration"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>

<xsl:function name="f:format-duration" as="xs:string">
  <xsl:param name="duration" as="xs:dayTimeDuration"/>
  <xsl:sequence select="f:format-duration($duration, false())"/>
</xsl:function>

<xsl:function name="f:format-duration" as="xs:string">
  <xsl:param name="duration" as="xs:dayTimeDuration"/>
  <xsl:param name="always-show-seconds" as="xs:boolean"/>

  <xsl:variable name="hours" select="abs(hours-from-duration($duration))"/>
  <xsl:variable name="minutes" select="abs(minutes-from-duration($duration))"/>
  <xsl:variable name="seconds" select="abs(xs:integer(seconds-from-duration($duration)))"/>

  <xsl:choose>
    <xsl:when test="$always-show-seconds or $duration lt $TEN-MINUTES">
      <xsl:sequence select="(if ($duration lt $ZERO-SECONDS) then '-' else '')
                            || string($hours)
                            || ':' || format-number($minutes, '00')
                            || ':' || format-number($seconds, '00')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:sequence select="(if ($duration lt $ZERO-SECONDS) then '-' else '')
                            || string($hours)
                            || ':' || format-number($minutes, '00')"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>

<xsl:function name="f:tumble-id" as="xs:string">
  <xsl:param name="item" as="node()"/>
  <xsl:choose>
    <xsl:when test="empty($item/parent::*)">
      <xsl:sequence select="'R'"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:sequence select="f:tumble-id($item/parent::*)
                            ||'.E'||count($item/preceding-sibling::*)"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>

<xsl:function name="f:store" as="xs:string?">
  <xsl:param name="key" as="xs:string"/>
  <xsl:param name="value" as="xs:string"/>
  <xsl:if test="$localStorageKey">
    <xsl:variable name="storage-key" select="$localStorageKey || '.' || $key"/>
    <xsl:sequence select="ixsl:call(ixsl:window(), 'localStorage.setItem',
                                    [$storage-key, $value])"/>
  </xsl:if>
</xsl:function>

<xsl:function name="f:get-property">
  <xsl:param name="key" as="xs:string"/>
  <xsl:sequence select="ixsl:get(ixsl:window(), 'manageSpeakerNotes.' || $key)"/>
</xsl:function>

<xsl:function name="f:set-property">
  <xsl:param name="key" as="xs:string"/>
  <xsl:param name="value" as="item()"/>
  <ixsl:set-property name="manageSpeakerNotes.{$key}"
                     select="$value"/>
</xsl:function>

</xsl:stylesheet>
