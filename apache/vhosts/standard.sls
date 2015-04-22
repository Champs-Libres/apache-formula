{% from "apache/map.jinja" import apache with context %}

{% set need_certificates = False %}

include:
  - apache

{% for id, site in salt['pillar.get']('apache:sites', {}).items() %}

{{ id }}:
  file:
    - managed
    - name: {{ apache.vhostdir }}/{{ id }}{{ apache.confext }}
    - source: {{ site.get('template_file', 'salt://apache/vhosts/standard.tmpl') }}
    - template: {{ site.get('template_engine', 'jinja') }}
    - context:
        id: {{ id|json }}
        site: {{ site|json }}
        map: {{ apache|json }}
    - require:
      - pkg: apache
    - watch_in:
      - module: apache-reload

{% if 'DocumentRoot' in site %}
{{ id }}-documentroot:
  file.directory:
    - unless: test -d {{ site.get('DocumentRoot') }}
    - name: {{ site.get('DocumentRoot') }}
    - makedirs: True
{% endif %}

{% if 'TLS' in site %}
{% set need_certificates = True %}

{{ apache.certificates_dir }}/{{ id }}/key.pem:
  file.managed:
    - user: root
    - group: {{ apache.group }}
    - mode: 640
    - template: jinja
    - source: salt://apache/vhosts/key.tmpl
    - id: {{ id }}
    - makedirs: True
#    - require: 
#      - file: {{ apache.certificates_dir }}/{{ id }}

{{ apache.certificates_dir }}/{{ id }}/{{ id }}.crt:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - id: {{ id }}
    - source: salt://apache/vhosts/crt.tmpl
#    - contents_pillar: apache:{{ id }}:TLS:crt
    - makedirs: True
#    - require: 
#      - file: {{ apache.certificates_dir }}/{{ id }}
    
{% endif %}

{% if grains.os_family == 'Debian' %}
a2ensite {{ id }}{{ apache.confext }}:
  cmd:
    - run
    - unless: test -f /etc/apache2/sites-enabled/{{ id }}{{ apache.confext }}
    - require:
      - file: /etc/apache2/sites-available/{{ id }}{{ apache.confext }}
    - watch_in:
      - module: apache-reload
{% endif %}

{% endfor %}

{% if need_certificates %}
{{ apache.certificates_dir }}:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 644

{{ apache.tls }}:
  pkg.installed: []

a2enmod tls:
  cmd.run:
    - unless: ls /etc/apache2/mods-enabled/tls.load
    - order: 225
    - require:
      - pkg: {{ apache.tls }}
    - watch_in:
      - module: apache-restart

a2dismod ssl:
  cmd.run:
    - onlyif: ls /etc/apache2/mods-enabled/ssl.load
    - order: 225
    - require:
      - pkg: {{ apache.tls }}
    - watch_in:
      - module: apache-restart

{% endif %}
