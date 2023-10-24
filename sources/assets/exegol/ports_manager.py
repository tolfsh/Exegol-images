import os
import json
import sys
import socket
from typing import Iterable
from R2Log import logger


logger.setVerbosity(3)  # Set DEBUG level

CONFIG = {
    "bloodhound": "/root/.config/bloodhound/config.json",
    "neo4j": "/etc/neo4j/neo4j.conf",
    "trilium": "/root/.local/share/trilium-data/config.ini",
}

DEFAULT_PORT = {
    "neo4j": {
        "bolt": 7687,
        "http": 7474,
        "https": 7373,
    },
    "trilium": 1991,
}

PORTS_DB = DEFAULT_PORT


def ports_already_set(d):
    if isinstance(d, dict):
        for v in d.values():
            yield from ports_already_set(v)
    elif isinstance(d, Iterable) and not isinstance(d, str):  # or list, set, ... only
        for v in d:
            yield from ports_already_set(v)
    else:
        yield d


def find_available_port():
    if os.environ.get('EXEGOL_RANDOMIZE_SERVICE_PORTS') == "true":
        logger.debug("EXEGOL_RANDOMIZE_SERVICE_PORTS is True")
        excluded_ports = list(ports_already_set(PORTS_DB))
        logger.debug(f"Exclusion list: {excluded_ports}")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('localhost', 0))
            port = s.getsockname()[1]
            while port in excluded_ports:
                port = find_available_port()
            return port
    else:
        logger.debug("EXEGOL_RANDOMIZE_SERVICE_PORTS is False")
        return None


def neo4j():
    logger.info("Setting ports for neo4j")
    PORTS_DB["neo4j"]["bolt"] = find_available_port() or DEFAULT_PORT["neo4"]["bolt"]
    logger.debug(f'Port for neo4j (bolt): {PORTS_DB["neo4j"]["bolt"]}')
    PORTS_DB["neo4j"]["http"] = find_available_port() or DEFAULT_PORT["neo4"]["http"]
    logger.debug(f'Port for neo4j (http): {PORTS_DB["neo4j"]["http"]}')
    PORTS_DB["neo4j"]["https"] = find_available_port() or DEFAULT_PORT["neo4"]["https"]
    logger.debug(f'Port for neo4j (https): {PORTS_DB["neo4j"]["https"]}')
    logger.verbose(f"Ports found: {PORTS_DB['neo4j']}")

    logger.verbose("Reading config file")
    with open(CONFIG["neo4j"], 'r') as neo4j_config:
        neo4j_conf = neo4j_config.readlines()
        logger.debug("")

    logger.verbose("Creating new config lines")
    for i, line in enumerate(neo4j_conf):
        if "dbms.connector.bolt.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.bolt.listen_address=:{PORTS_DB["neo4j"]["bolt"]}\n'
            logger.debug(neo4j_conf[i].strip())
        elif "dbms.connector.http.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.http.listen_address=:{PORTS_DB["neo4j"]["http"]}\n'
            logger.debug(neo4j_conf[i].strip())
        elif "dbms.connector.https.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.https.listen_address=:{PORTS_DB["neo4j"]["https"]}\n'
            logger.debug(neo4j_conf[i].strip())

    logger.verbose("Writing config to file")
    with open(CONFIG["neo4j"], 'w') as neo4j_config:
        neo4j_config.writelines(neo4j_conf)

    logger.info("Updating BloodHound config")
    with open(CONFIG["bloodhound"], 'r') as bloodhound_config:
        logger.verbose("Loading current config")
        bloodhound_conf = json.load(bloodhound_config)

    logger.verbose("Creating new config")
    bloodhound_conf['databaseInfo']['url'] = f"bolt://localhost:{PORTS_DB['neo4j']['bolt']}"
    logger.debug(f"databaseInfo['url']: {bloodhound_conf['databaseInfo']['url']}")

    logger.verbose("Writing config to file")
    with open(CONFIG["bloodhound"], 'w') as bloodhound_config:
        json.dump(bloodhound_conf, bloodhound_config, indent=4)


def trilium():
    logger.info("Setting port for trilium")
    logger.debug(f'Port for trilium: {PORTS_DB["neo4j"]["https"]}')
    PORTS_DB["trilium"] = find_available_port() or DEFAULT_PORT["trilium"]
    logger.verbose(f"Ports found: {PORTS_DB['trilium']}")

    logger.verbose("Reading config file")
    with open(CONFIG["trilium"], 'r') as trilium_config:
        trilium_conf = trilium_config.readlines()

    logger.verbose("Creating new config lines")
    for i, line in enumerate(trilium_conf):
        if line.startswith('port='):
            trilium_conf[i] = f'port={PORTS_DB["trilium"]}\n'
            logger.debug(trilium_conf[i].strip())

    logger.verbose("Writing config to file")
    with open(CONFIG["trilium"], 'w') as trilium_config:
        trilium_config.writelines(trilium_conf)


def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py [service]")
        return

    service = sys.argv[1]
    if service == "neo4j":
        neo4j()
    elif service == "trilium":
        trilium()
    else:
        print("Service not supported")


if __name__ == "__main__":
    main()
