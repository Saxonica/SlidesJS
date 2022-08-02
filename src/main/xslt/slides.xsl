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

<xsl:variable name="ZERO-SECONDS" select="xs:dayTimeDuration('PT0S')"/>
<xsl:variable name="ONE-SECOND" select="xs:dayTimeDuration('PT1S')"/>
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
      <xsl:sequence select="f:set-property('lastUpdate', string(saxon:timestamp()))"/>
      <ixsl:schedule-action wait="$update-interval">
        <xsl:call-template name="updateSlides"/>
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
    <span>
      <xsl:text>SlidesJS version </xsl:text>
      <xsl:sequence select="f:get-property('slidesJSVersion')"/>
    </span>
    <ixsl:schedule-action wait="3000">
      <xsl:call-template name="fixPageLinks"/>
    </ixsl:schedule-action>
  </xsl:result-document>

  <xsl:if test="$countdown-timer or $talk-duration gt $ZERO-SECONDS">
    <xsl:result-document href="#slidesjs_time_reset" method="ixsl:replace-content">
      <xsl:text>reset</xsl:text>
    </xsl:result-document>
  </xsl:if>

  <xsl:result-document href="#slidesjs_copyright" method="ixsl:replace-content">
    <xsl:sequence select="/html/body/main/header/div[contains-token(@class, 'copyright')]/node()"/>
  </xsl:result-document>
</xsl:template>

<xsl:template name="fixPageLinks">
  <xsl:result-document href="#slidesjs_nav" method="ixsl:replace-content">
    <a href="https://saxonica.github.io/SlidesJS/help.html">help?</a>
    <xsl:text> </xsl:text>
    <span class="link" x-slide="toc">contents?</span>
    <xsl:text> </xsl:text>
    <span class="link" x-slide="0">restart?</span>
  </xsl:result-document>
</xsl:template>

<xsl:template name="updateSlides">
  <xsl:variable name="stateChange" select="ixsl:call(ixsl:window(), 'slidesPopEvent', [])"/>
  <xsl:choose>
    <xsl:when test="exists($stateChange)">
      <xsl:variable name="state" select="ixsl:get($stateChange, 'state')"/>
      <xsl:variable name="value" select="ixsl:get($stateChange, 'value')"/>

      <!-- <xsl:message select="$state, '=', $value"/> -->

      <xsl:choose>
        <xsl:when test="$state = 'currentPage' or $state = 'reload'">
          <xsl:call-template name="render-slide"/>
        </xsl:when>
        <xsl:when test="$state = 'duration'">
          <xsl:sequence select="f:set-property($state, xs:dayTimeDuration($value))"/>
        </xsl:when>
        <xsl:when test="$state = 'startTime'">
          <xsl:sequence select="f:set-property($state, xs:dateTime($value))"/>
        </xsl:when>
        <xsl:when test="$state = 'paused'">
          <xsl:sequence select="f:set-property($state, string($value) = 'true')"/>
        </xsl:when>
        <xsl:when test="$state = 'reveal'">
          <xsl:if test="$value != ''">
            <xsl:sequence select="f:set-property('last-'||$state, $value)"/>
            <xsl:variable name="element"
                          select="ixsl:page()//*[@id = $value]"/>
            <xsl:if test="exists($element)">
              <ixsl:set-attribute name="class"
                                  select="'revealed'"
                                  object="$element"/>
            </xsl:if>
          </xsl:if>
        </xsl:when>
        <xsl:when test="$state = 'reveal-all'">
          <xsl:if test="$value != ''">
            <xsl:sequence select="f:set-property('last-'||$state, $value)"/>
            <xsl:for-each select="tokenize($value, '\s+')">
              <xsl:variable name="id" select="."/>
              <xsl:variable name="element"
                            select="ixsl:page()//*[@id = $id]"/>
              <xsl:if test="exists($element)">
                <ixsl:set-attribute name="class"
                                    select="'revealed'"
                                    object="$element"/>
              </xsl:if>
            </xsl:for-each>
          </xsl:if>
        </xsl:when>
        <xsl:when test="$state = 'unreveal'">
          <xsl:if test="$value != ''">
            <xsl:sequence select="f:set-property('last-'||$state, $value)"/>
            <xsl:variable name="element"
                          select="ixsl:page()//*[@id = $value]"/>
            <xsl:if test="exists($element)">
              <ixsl:set-attribute name="class"
                                  select="'unrevealed'"
                                  object="$element"/>
            </xsl:if>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'Unexpected event: ' || $state || '=' || $value"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <!-- If there's no event pending, then once a second update the
           timer if it's being used. Alternatively, the updateTime
           template could be running in its own schedule-action loop,
           but that introduces race conditions, so this is simpler. -->
      <xsl:variable name="lastUpdate" select="f:get-property('lastUpdate')"/>
      <xsl:if test="($countdown-timer or $talk-duration gt $ZERO-SECONDS)
                    and $lastUpdate castable as xs:dateTime
                    and saxon:timestamp() - xs:dateTime($lastUpdate) gt $ONE-SECOND">
        <xsl:call-template name="updateTime"/>
        <xsl:sequence select="f:set-property('lastUpdate', string(saxon:timestamp()))"/>
      </xsl:if>

      <!-- The localStorage API only transmits changed values; make sure
           we clear an reveal values. If we don't, some combinations of
           page navigation and reveal will fail to transmit the correct
           reveal value. At the same time, we have to make sure that we
           don't set and then reset the value in the same execution because
           then the localStorage API never sees the correct value. So
           we have this thing where we only reset them when there aren't
           any state changes to consume. -->
      <xsl:for-each select="('reveal', 'unreveal', 'reveal-all')">
        <xsl:variable name="key" select="'last-'||."/>
        <xsl:if test="f:get-property($key) != ''">
          <xsl:sequence select="f:set-property($key, '')"/>
          <xsl:sequence select="f:push(., '')"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>

  <ixsl:schedule-action wait="$update-interval">
    <xsl:call-template name="updateSlides"/>
  </ixsl:schedule-action>
</xsl:template>

<xsl:template name="updateTime">
  <xsl:variable name="paused" select="f:get-property('paused')"/>
  <xsl:variable name="start" select="xs:dateTime(f:get-property('startTime'))"/>
  <xsl:variable name="savedDuration" select="xs:dayTimeDuration(f:get-property('duration'))"/>

  <xsl:variable name="duration" as="xs:dayTimeDuration">
    <xsl:choose>
      <xsl:when test="$paused">
        <xsl:sequence select="xs:dayTimeDuration('PT0S')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="saxon:timestamp() - $start"/>
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
      <xsl:text> (progressive)</xsl:text>
    </xsl:if>
  </xsl:result-document>
</xsl:template>

<!-- ============================================================ -->

<xsl:template name="render-slide">
  <xsl:variable name="href"
                select="ixsl:get(ixsl:window(), 'location.href')"/>
  <xsl:variable name="hash" select="substring-after($href, '#')"/>

  <xsl:choose>
    <xsl:when test="$hash castable as xs:integer">
      <xsl:variable name="slideno" select="xs:integer($hash)"/>
      <xsl:if test="$slideno ge 0 and $slideno le $last-slideno">
        <xsl:call-template name="render-individual-slide">
          <xsl:with-param name="slideno" select="$slideno"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:when>
    <xsl:when test="normalize-space($hash) = ''">
      <xsl:call-template name="render-individual-slide">
        <xsl:with-param name="slideno" select="0"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$hash = 'x'">
      <xsl:call-template name="render-all-slides"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message select="'Cannot render', $href"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="render-individual-slide">
  <xsl:param name="slideno" as="xs:integer"/>

  <ixsl:set-property name="location.hash"
                     select="if ($slideno = 0)
                             then ''
                             else if ($slideno lt 0)
                                  then 'x'
                                  else $slideno"/>

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

  <xsl:sequence select="ixsl:call(ixsl:window(), 'forceHighlight', [])"/>

  <xsl:result-document href="#slidesjs_main" method="ixsl:replace-content">
    <xsl:apply-templates select="f:slide($slideno)"/>
  </xsl:result-document>

  <xsl:result-document href="#slidesjs_pageno" method="ixsl:replace-content">
    <xsl:sequence select="$slideno || ' of ' || $last-slideno"/>
  </xsl:result-document>
</xsl:template>

<xsl:template name="render-all-slides">
  <xsl:result-document href="#slidesjs_main" method="ixsl:replace-content">
    <xsl:apply-templates select="f:slide(0)"/>
    <div class="s_toc">
      <header>
        <h1>Table of Contents</h1>
      </header>
      <div>
        <xsl:apply-templates select="$slides/html/body/main" mode="toc"/>
      </div>
    </div>
    <xsl:for-each select="1 to $last-slideno">
      <p>Slide <xsl:sequence select="."/>:</p>
      <xsl:apply-templates select="f:slide(.)"/>
    </xsl:for-each>
  </xsl:result-document>

  <ixsl:set-attribute name="class"
                      select="'none'"
                      object="ixsl:page()/html/body"/>

  <xsl:sequence select="ixsl:call(ixsl:window(), 'forceHighlight', [])"/>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="h:main/h:header" priority="200"> 
  <div class="s_titlepage">
    <xsl:next-match/>
  </div>
</xsl:template>

<xsl:template match="h:section" priority="200"> 
  <div class="s_section">
    <xsl:next-match/>
  </div>
</xsl:template>

<xsl:template match="h:div[contains-token(@class, 'slide')]" priority="200">
  <div class="s_slide">
    <xsl:next-match/>
  </div>
</xsl:template>

<xsl:template match="h:main/h:header|h:section|h:div[contains-token(@class, 'slide')]"
              priority="100"> 
  <div class="{if (f:get-property('showNotes')) then 'slidenotes' else 'slide'}">
    <xsl:next-match/>
  </div>
  <xsl:apply-templates select="h:aside" mode="notes"/>
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
                        or ancestor::ol[contains-token(@class, 'progressive')]"/>
  <li>
    <xsl:sequence select="@* except @class"/>
    <xsl:if test="not(@id)">
      <xsl:attribute name="id" select="f:tumble-id(.)"/>
    </xsl:if>
    <xsl:if test="$progressive and (preceding-sibling::li or ancestor::li)">
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
  <xsl:call-template name="navigate">
    <xsl:with-param name="key" select="ixsl:get(ixsl:event(), 'key')"/>
  </xsl:call-template>
</xsl:template>

<xsl:template name="navigate">
  <xsl:param name="key" as="xs:string"/>
  <xsl:variable name="slideno" select="f:slideno()"/>

  <xsl:variable name="hidden"
                select="ixsl:page()//*[contains-token(@class, 'unrevealed')]"/>
  <xsl:variable name="revealed"
                select="ixsl:page()//*[contains-token(@class, 'revealed')]"/>

  <xsl:choose>
    <xsl:when test="$key = 'n' and $slideno lt $last-slideno">
      <ixsl:set-property name="location.hash" select="$slideno + 1"/>
    </xsl:when>

    <xsl:when test="($key = ' ' or $key = 'ArrowRight' or $key = 'ArrowDown') and $hidden">
      <xsl:sequence select="f:push('reveal', string($hidden[1]/@id))"/>
    </xsl:when>

    <xsl:when test="($key = ' ' or $key = 'ArrowRight' or $key = 'ArrowDown')
                    and $slideno lt $last-slideno">
      <ixsl:set-property name="location.hash" select="$slideno + 1"/>
    </xsl:when>

    <xsl:when test="$key = 'p' and $slideno gt 0">
      <ixsl:set-property name="location.hash" select="$slideno - 1"/>
    </xsl:when>

    <xsl:when test="($key = 'ArrowLeft' or $key = 'ArrowUp') and $revealed">
      <xsl:sequence select="f:push('unreveal', string($revealed[last()]/@id))"/>
    </xsl:when>

    <xsl:when test="($key = 'ArrowLeft' or $key = 'ArrowUp')
                    and $slideno gt 0">
      <ixsl:set-property name="location.hash" select="$slideno - 1"/>
    </xsl:when>

    <xsl:when test="$key = 'h'">
      <ixsl:set-property name="location.hash" select="''"/>
    </xsl:when>

    <xsl:when test="$key = 'a' and $hidden">
      <xsl:sequence select="f:push('reveal-all', string-join($hidden/@id, ' '))"/>
    </xsl:when>

    <xsl:when test="$key = 's'">
      <xsl:sequence select="f:set-property('showNotes', not(f:get-property('showNotes')))"/>
      <xsl:sequence select="f:push('reload', string(saxon:timestamp()))"/>
    </xsl:when>

    <xsl:when test="$key = 't'">
      <xsl:variable name="toc-div" select="(ixsl:page()//h:div[@id = 'slidesjs_toc'])[1]"/>
      <ixsl:set-attribute name="class" object="$toc-div"
                          select="if (contains-token($toc-div/@class, 'hidden'))
                                  then 'block'
                                  else 'hidden'"/>
    </xsl:when>

    <xsl:when test="$key = 'x' and $slideno lt 0">
      <xsl:variable name="return"
                    select="if (f:get-property('returnTo') castable as xs:integer)
                            then xs:integer(f:get-property('returnTo'))
                            else ''"/>
      <ixsl:set-property name="location.hash" select="$return"/>
    </xsl:when>

    <xsl:when test="$key = 'x'">
      <xsl:sequence select="f:set-property('returnTo', $slideno)"/>
      <ixsl:set-property name="location.hash" select="'x'"/>
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
  <xsl:variable name="paused" select="f:get-property('paused')"/>
  <xsl:choose>
    <xsl:when test="$paused">
      <!-- we're unpausing, reset the start time -->
      <xsl:sequence select="f:push('startTime', string(saxon:timestamp()))"/>
    </xsl:when>
    <xsl:otherwise>
      <!-- we're pausing, save the duration -->
      <xsl:variable name="start" select="xs:dateTime(f:get-property('startTime'))"/>
      <xsl:variable name="total"
                    select="f:rounded-duration(xs:dayTimeDuration(f:get-property('duration'))
                                               + (saxon:timestamp() - $start))"/>
      <xsl:sequence select="f:push('duration', string($total))"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:sequence select="f:push('paused', string(not($paused)))"/>
</xsl:template>

<xsl:template match="h:span[@id='slidesjs_time_reset']" mode="ixsl:onclick">
  <xsl:sequence select="f:push('paused', 'true')"/>
  <xsl:sequence select="f:push('duration', 'PT0S')"/>
</xsl:template>

<xsl:template match="h:span[contains-token(@class, 'link')]" mode="ixsl:onclick">
  <xsl:choose>
    <xsl:when test="@x-slide castable as xs:integer">
      <xsl:variable name="slideno" select="xs:integer(@x-slide)"/>
      <ixsl:set-property name="location.hash"
                         select="if ($slideno = 0)
                                 then ''
                                 else if ($slideno lt 0)
                                      then 'x'
                                      else $slideno"/>
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

<xsl:template match="*" mode="ixsl:ontouchstart">
  <xsl:variable name="touches" select="ixsl:get(ixsl:event(), 'touches')"/>
  <xsl:variable name="fingers" select="ixsl:get($touches, 'length')"/>

  <xsl:if test="$fingers = 1">
    <xsl:variable name="touch" select="ixsl:get($touches, '0')"/>
    <xsl:variable name="clientX" select="ixsl:get($touch, 'clientX')"/>
    <xsl:variable name="clientY" select="ixsl:get($touch, 'clientY')"/>

    <xsl:variable name="width" select="ixsl:get(ixsl:window(), 'innerWidth')"/>
    <xsl:variable name="height" select="ixsl:get(ixsl:window(), 'innerHeight')"/>

    <!-- Assume this is just an edge click. -->
    <xsl:sequence select="f:set-property('touchX', '')"/>
    <xsl:sequence select="f:set-property('touchY', '')"/>

    <xsl:choose>
      <xsl:when test="$width and $clientX div $width lt 0.2">
        <xsl:call-template name="navigate">
          <xsl:with-param name="key" select="'ArrowLeft'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$width and $clientX div $width gt 0.8">
        <xsl:call-template name="navigate">
          <xsl:with-param name="key" select="'ArrowRight'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$height and $clientY div $height lt 0.2">
        <xsl:call-template name="navigate">
          <xsl:with-param name="key" select="'ArrowUp'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$height and $clientY div $height gt 0.8">
        <xsl:call-template name="navigate">
          <xsl:with-param name="key" select="'ArrowDown'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <!-- It wasn't an edge click, hold onto the positions. -->
        <xsl:sequence select="f:set-property('touchX', $clientX)"/>
        <xsl:sequence select="f:set-property('touchY', $clientY)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template match="*" mode="ixsl:ontouchend">
  <xsl:variable name="touches" select="ixsl:get(ixsl:event(), 'changedTouches')"/>
  <xsl:variable name="fingers" select="ixsl:get($touches, 'length')"/>

  <xsl:if test="$fingers = 1">
    <xsl:variable name="touch" select="ixsl:get($touches, '0')"/>
    <xsl:variable name="clientX" select="ixsl:get($touch, 'clientX')"/>
    <xsl:variable name="initialX" select="f:get-property('touchX')"/>

    <xsl:if test="$initialX">
      <xsl:variable name="width" select="ixsl:get(ixsl:window(), 'innerWidth')"/>
      <xsl:variable name="deltaX" select="$clientX - $initialX"/>
      <xsl:variable name="percX" select="abs($deltaX) div $width"/>

      <!-- Ignore "swipes" that cover less than 5% of the device width -->
      <xsl:if test="$percX gt 0.05">
        <xsl:choose>
          <xsl:when test="$deltaX gt 0">
            <xsl:call-template name="navigate">
              <xsl:with-param name="key" select="'p'"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="navigate">
              <xsl:with-param name="key" select="'n'"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>

        <xsl:sequence select="f:set-property('initialX', '')"/>
        <xsl:sequence select="f:set-property('initialY', '')"/>
        <xsl:sequence select="f:set-property('clientX', '')"/>
        <xsl:sequence select="f:set-property('clientY', '')"/>
      </xsl:if>
    </xsl:if>
  </xsl:if>
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

  <xsl:variable name="id" select="substring-after($hash, '#')"/>

  <xsl:sequence select="if ($id castable as xs:integer)
                        then xs:integer($id)
                        else if ($id = 'x')
                             then -1
                             else 0"/>
</xsl:function>

<xsl:function name="f:slide" as="element()">
  <xsl:param name="slideno" as="xs:integer"/>

  <xsl:variable name="main" select="$slides/h:html/h:body/h:main"/>

  <xsl:choose>
    <xsl:when test="$slideno = 0">
      <xsl:sequence select="$main/h:header"/>
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

<xsl:function name="f:get-property">
  <xsl:param name="key" as="xs:string"/>
  <xsl:sequence select="ixsl:get(ixsl:window(), 'manageSlides.' || $key)"/>
</xsl:function>

<xsl:function name="f:set-property">
  <xsl:param name="key" as="xs:string"/>
  <xsl:param name="value" as="item()"/>
  <ixsl:set-property name="manageSlides.{$key}" select="$value"/>
</xsl:function>

<xsl:function name="f:push">
  <xsl:param name="key" as="xs:string"/>
  <xsl:param name="value" as="item()"/>
  <xsl:sequence select="ixsl:call(ixsl:window(), 'slidesPushEvent', [$key, $value])"/>
</xsl:function>

</xsl:stylesheet>
