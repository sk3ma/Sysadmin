#!/usr/bin/env bash

mkdir -p roles/elk_stack/{defaults,handlers,meta,tasks,templates,vars,molecule/default}

# defaults/
cat > roles/elk_stack/defaults/main.yml <<'STOP'
---
elasticsearch_package: elasticsearch
logstash_package: logstash
kibana_package: kibana
STOP

# handlers/
cat > roles/elk_stack/handlers/main.yml <<'STOP'
---
- name: restart elasticsearch
  ansible.builtin.systemd:
    name: elasticsearch
    state: restarted
- name: restart logstash
  ansible.builtin.systemd:
    name: logstash
    state: restarted
- name: restart kibana
  ansible.builtin.systemd:
    name: kibana
    state: restarted
STOP

# tasks/
cat > roles/elk_stack/tasks/main.yml <<'STOP'
---
- include_tasks: elasticsearch.yml
- include_tasks: logstash.yml
- include_tasks: kibana.yml
STOP

cat > roles/elk_stack/tasks/elasticsearch.yml <<'STOP'
---
- name: Install Elasticsearch
  ansible.builtin.dnf:
    name: "{{ elasticsearch_package }}"
    state: present
- name: Ensure Elasticsearch running
  ansible.builtin.systemd:
    name: elasticsearch
    state: started
    enabled: true
  notify: restart elasticsearch
STOP

cat > roles/elk_stack/tasks/logstash.yml <<'STOP'
---
- name: Install Logstash
  ansible.builtin.dnf:
    name: "{{ logstash_package }}"
    state: present
- name: Deploy Logstash configuration
  ansible.builtin.template:
    src: logstash.conf.j2
    dest: /etc/logstash/conf.d/logstash.conf
  notify: restart logstash
- name: Ensure Logstash running
  ansible.builtin.systemd:
    name: logstash
    state: started
    enabled: true
STOP

cat > roles/elk_stack/tasks/kibana.yml <<'STOP'
---
- name: Install Kibana
  ansible.builtin.dnf:
    name: "{{ kibana_package }}"
    state: present
- name: Deploy Kibana config
  ansible.builtin.template:
    src: kibana.yml.j2
    dest: /etc/kibana/kibana.yml
  notify: restart kibana
- name: Ensure Kibana running
  ansible.builtin.systemd:
    name: kibana
    state: started
    enabled: true
STOP

# templates/
cat > roles/elk_stack/templates/logstash.conf.j2 <<'STOP'
input {
  file {
    path => "/var/log/messages"
    start_position => "beginning"
  }
}
filter {
  grok { match => { "message" => "%{SYSLOGBASE}" } }
}
output {
  elasticsearch { hosts => ["localhost:9200"]; index => "syslog" }
}
STOP

cat > roles/elk_stack/templates/kibana.yml.j2 <<'STOP'
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
STOP

# molecule/
cat > roles/elk_stack/molecule/default/molecule.yml <<'STOP'
---
driver:
  name: docker
platforms:
  - name: rockylinux9
    image: rockylinux:9
    privileged: true
    command: /sbin/init
provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
verifier:
  name: ansible
  playbooks:
    - verify.yml
STOP

cat > roles/elk_stack/molecule/default/converge.yml <<'STOP'
---
- hosts: all
  become: true
  roles:
    - role: elk_stack
STOP

cat > roles/elk_stack/molecule/default/prepare.yml <<'STOP'
---
- hosts: all
  become: true
  tasks:
    - name: Update package metadata
      ansible.builtin.dnf:
        update_cache: true
STOP

cat > roles/elk_stack/molecule/default/verify.yml <<'STOP'
---
- hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Check Elasticsearch
      ansible.builtin.command: systemctl is-active elasticsearch
      register: elastic
      changed_when: false
      failed_when: elastic.rc != 0
    - name: Check Logstash
      ansible.builtin.command: systemctl is-active logstash
      register: logstash
      changed_when: false
      failed_when: logstash.rc != 0
    - name: Check Kibana
      ansible.builtin.command: systemctl is-active kibana
      register: kibana
      changed_when: false
      failed_when: kibana.rc != 0
STOP
