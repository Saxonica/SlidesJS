<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 	        xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
                xmlns:f="https://nwalsh.com/ns/org-to-xml/functions"
                xmlns:js="http://saxonica.com/ns/globalJS"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:ox="https://nwalsh.com/ns/org-to-xml"
                xmlns:saxon="http://saxon.sf.net/"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="ixsl f js map ox saxon xs"
                version="3.0">

<xsl:output method="html" html-version="5" encoding="utf-8" indent="no"/>

<xsl:variable name="seropt" select="map{'method':'xml','indent':true()}"/>

<xsl:variable name="update-interval" select="50"/>

<xsl:variable name="slides" select="/"/>
<xsl:variable name="last-slideno" select="count(//ox:headline)"/>

<xsl:variable name="localStorageKey"
              select="ixsl:page()/html/head/meta[@name='localStorage.key']/@content/string()"/>

<xsl:template match="/">
  <ixsl:schedule-action wait="$update-interval">
    <xsl:call-template name="updateSpeakerNotes"/>
  </ixsl:schedule-action>
  <xsl:call-template name="render-slide">
    <xsl:with-param name="slideno" select="f:slideno()"/>
  </xsl:call-template>
  <xsl:result-document href="#copyright" method="ixsl:replace-content">
    <xsl:sequence select="/ox:document/ox:keyword[@key='COPYRIGHT']/@value/string()"/>
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
                     select="if ($slideno = 0)
                             then ''
                             else $slideno"/>
  
  <ixsl:set-attribute name="class"
                      select="if ($slideno = 0)
                              then 'titlepage'
                              else 'slide'"
                      object="ixsl:page()/html/body"/>

  <xsl:result-document href="#main" method="ixsl:replace-content">
    <xsl:choose>
      <xsl:when test="$slideno = 0">
        <xsl:apply-templates select="$slides/ox:document"/>
      </xsl:when>
      <xsl:when test="$slideno le $last-slideno">
        <xsl:apply-templates select="$slides/ox:document/ox:headline[position() = $slideno]"/>
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
  </xsl:result-document>

  <xsl:result-document href="#pageno" method="ixsl:replace-content">
    <xsl:sequence select="$slideno || ' of ' || count($slides//ox:headline)"/>
  </xsl:result-document>

  <xsl:sequence select="ixsl:call(ixsl:window(), 'forceHighlight', array{})"/>
  <xsl:sequence select="f:set-property('currentPage', ixsl:get(ixsl:window(), 'location.href'))"/>
</xsl:template>

<xsl:template match="ox:document">
  <header>
    <xsl:apply-templates select="ox:keyword[@key='TITLE']"/>
    <xsl:apply-templates select="ox:keyword[@key='SUBTITLE']"/>
    <xsl:apply-templates select="ox:keyword[@key='DATE']"/>
    <xsl:apply-templates select="ox:keyword[@key='AUTHOR']"/>
    <xsl:apply-templates select="ox:keyword[@key='CONFERENCE']"/>
  </header>
  <xsl:apply-templates select="* except (ox:headline|ox:keyword)"/>
</xsl:template>

<xsl:template match="ox:structure|ox:property-drawer|ox:node-property|ox:keyword"/>

<xsl:template match="ox:keyword[@key='CSS']">
  <link rel="stylesheet" href="{@value}"/>
</xsl:template>

<xsl:template match="ox:keyword[@key='JAVASCRIPT']">
  <script src="{@value}"></script>
</xsl:template>

<xsl:template match="ox:keyword[@key='TITLE']">
  <h1 class="{lower-case(@key)}">
    <xsl:sequence select="@value/string()"/>
  </h1>
</xsl:template>

<xsl:template match="ox:keyword[@key='SUBTITLE']">
  <h2 class="{lower-case(@key)}">
    <xsl:sequence select="@value/string()"/>
  </h2>
</xsl:template>

<xsl:template match="ox:keyword[@key='DATE']">
  <h2 class="{lower-case(@key)}">
    <xsl:choose>
      <xsl:when test="@value castable as xs:date">
        <xsl:variable name="date" select="xs:date(@value)"/>
        <xsl:attribute name="datetime" select="@value"/>
        <xsl:sequence select="format-date($date, '[D01] [MNn,*-3] [Y0001]')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="@value/string()"/>
      </xsl:otherwise>
    </xsl:choose>
  </h2>
</xsl:template>

<xsl:template match="ox:keyword[@key='AUTHOR']">
  <h2 class="{lower-case(@key)}">
    <xsl:sequence select="@value/string()"/>
  </h2>
</xsl:template>

<xsl:template match="ox:keyword[@key='CONFERENCE']">
  <h2 class="{lower-case(@key)}">
    <xsl:sequence select="@value/string()"/>
  </h2>
</xsl:template>

<xsl:template match="ox:headline">
  <div>
    <div class="{if (f:get-property('showNotes'))
                 then 'headnotes'
                 else 'headline'}">
      <h1>
        <xsl:choose>
          <xsl:when test="ox:title">
            <xsl:apply-templates select="ox:title"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="@raw-value/string()"/>
          </xsl:otherwise>
        </xsl:choose>
      </h1>
      <xsl:apply-templates select="* except ox:title"/>
    </div>
    <xsl:apply-templates select=".//ox:speakernotes" mode="notes"/>
  </div>
</xsl:template>

<xsl:template match="ox:title">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="ox:section">
  <section>
    <xsl:apply-templates/>
  </section>
</xsl:template>

<xsl:template match="ox:plain-list[@type = 'unordered']">
  <ul>
    <xsl:if test="f:reveal(.) = 'progressive'">
      <xsl:attribute name="class" select="f:reveal(.)"/>
    </xsl:if>
    <xsl:apply-templates select="ox:item"/>
  </ul>
</xsl:template>

<xsl:template match="ox:plain-list[@type = 'ordered']">
  <ol>
    <xsl:if test="f:reveal(.) = 'progressive'">
      <xsl:attribute name="class" select="f:reveal(.)"/>
    </xsl:if>
    <xsl:if test="ox:item[@counter]">
      <xsl:attribute name="start" select="(ox:item/@counter)[1]"/>
    </xsl:if>
    <xsl:apply-templates select="ox:item"/>
  </ol>
</xsl:template>

<xsl:template match="ox:item">
  <li id="{f:tumble-id(.)}">
    <xsl:if test="(preceding-sibling::ox:item or ancestor::ox:item)
                  and f:reveal(.) = 'progressive'">
      <xsl:attribute name="class" select="'unrevealed'"/>
    </xsl:if>
    <xsl:apply-templates/>
  </li>
</xsl:template>

<xsl:template match="ox:src-block">
  <xsl:variable name="classes" as="xs:string+">
    <xsl:sequence select="'programlisting'"/>
    <xsl:sequence select="'verbatim'"/>
    <xsl:sequence select="@language ! concat('language-', .)"/>
  </xsl:variable>
  <pre>
    <xsl:attribute name="class" select="string-join($classes, ' ')"/>
    <xsl:apply-templates/>
  </pre>
</xsl:template>

<xsl:template match="ox:speakernotes">
  <!-- suppressed by default -->
</xsl:template>

<xsl:template match="ox:speakernotes" mode="notes">
  <div class="{if (f:get-property('showNotes'))
               then 'shownotes'
               else 'speakernotes'}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ox:paragraph">
  <p>
    <xsl:apply-templates/>
  </p>
</xsl:template>

<xsl:template match="ox:paragraph[ox:caption]">
  <xsl:variable name="attr-html"
                select="f:parse-attr(ox:attr_html/text())"/>
  <figure>
    <xsl:if test="@name">
      <xsl:attribute name="id" select="@name"/>
    </xsl:if>
    <xsl:apply-templates select="ox:link" mode="img">
      <xsl:with-param name="attr-html" select="$attr-html"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="ox:caption"/>
  </figure>
</xsl:template>

<xsl:template match="ox:caption">
  <figcaption>
    <xsl:apply-templates/>
  </figcaption>
</xsl:template>

<xsl:template match="ox:link[@raw-link]" mode="img">
  <xsl:param name="attr-html" as="map(*)?"/>
  <img src="{@raw-link}">
    <xsl:for-each select="('width', 'height', 'alt')">
      <xsl:if test="map:contains($attr-html, .)">
        <xsl:attribute name="{.}" select="map:get($attr-html, .)"/>
      </xsl:if>
    </xsl:for-each>
  </img>
</xsl:template>

<xsl:template match="ox:link">
  <a href="{@raw-link}">
    <xsl:choose>
      <xsl:when test="empty(node())">
        <xsl:sequence select="@raw-link/string()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </a>
</xsl:template>

<xsl:template match="ox:verbatim">
  <code><xsl:sequence select="@value/string()"/></code>
</xsl:template>

<xsl:template match="ox:italic">
  <em><xsl:apply-templates/></em>
</xsl:template>

<xsl:template match="ox:bold">
  <strong><xsl:apply-templates/></strong>
</xsl:template>

<xsl:template match="ox:strike-through">
  <span class="strike"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="*">
  <div>
    <div style="color:red">
      <xsl:sequence select="local-name(.)"/>
    </div>
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
    <xsl:when test="($key = 'ArrowRight' or $key = 'ArrowDown') and $hidden">
      <ixsl:set-attribute name="class"
                          select="'revealed'"
                          object="$hidden[1]"/>
      <xsl:if test="$localStorageKey">
        <xsl:sequence select="f:store('reveal', $hidden[1]/@id)"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="($key = 'ArrowRight' or $key = 'ArrowDown')
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
    <xsl:when test="$key = 's' and $hidden">
      <xsl:for-each select="$hidden">
        <ixsl:set-attribute name="class"
                            select="'revealed'"
                            object="."/>
      </xsl:for-each>
    </xsl:when>
    <xsl:when test="$key = '!'">
      <xsl:sequence select="f:set-property('showNotes', not(f:get-property('showNotes')))"/>
      <xsl:call-template name="render-slide">
        <xsl:with-param name="slideno"
                        select="f:slideno()"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message select="'Unexpected key ' || $key || ' on '
        || $slideno || ' of ' || $last-slideno"/>
    </xsl:otherwise>
  </xsl:choose>
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

<xsl:function name="f:parse-attr" as="map(*)">
  <xsl:param name="attr" as="xs:string"/>
  <xsl:variable name="parts" select="tokenize(substring($attr, 2), ' :')"/>
  <xsl:sequence select="f:parse-list($parts, map{})"/>
</xsl:function>

<xsl:function name="f:parse-list" as="map(*)">
  <xsl:param name="list" as="xs:string*"/>
  <xsl:param name="map" as="map(*)"/>

  <xsl:variable name="key" select="substring-before($list[1], ' ')"/>
  <xsl:variable name="value" select="substring-after($list[1], ' ')"/>

  <xsl:choose>
    <xsl:when test="empty($list)">
      <xsl:sequence select="$map"/>
    </xsl:when>
    <xsl:when test="$key = 'alt'">
      <xsl:sequence
          select="map:put($map, $key,
                    string-join(($value, $list[position() gt 1]), ' '))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:sequence select="f:parse-list(
        $list[position() gt 1],
        map:put($map, $key, $value))"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>

<xsl:function name="f:reveal" as="xs:string?">
  <xsl:param name="context" as="node()"/>

  <xsl:variable name="properties"
                select="$context/ancestor::ox:headline/ox:section/ox:property-drawer"/>

  <xsl:sequence
      select="$properties/ox:node-property[upper-case(@key) = 'REVEAL']/@value/string()"/>
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
