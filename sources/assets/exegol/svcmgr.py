#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Author             : The Exegol Project
# Date created       : 3 Nov 2023
import argparse
import os
import json
import socket
import sqlite3
from R2Log import logger
from rich.console import Console
from rich.table import Table

CONFIG = {
    "bloodhound": "/root/.config/bloodhound/config.json",
    "neo4j": "/etc/neo4j/neo4j.conf",
    "trilium": "/root/.local/share/trilium-data/config.ini",
    "burp": "/opt/tools/BurpSuiteCommunity/conf.json"
}

SERVICES = ["neo4j", "trilium", "burp"]

DEFAULT_PORT = {
    "neo4j": {
        "bolt": 7687,
        "http": 7474,
        "https": 7373,
    },
    "trilium": 1991,
    "burp": 8080
}

SET_PORTS_DB = "/.exegol/.services.sqlite"
# SET_PORTS_DB = "services.sqlite"


def display_ports_table():
    logger.debug("Printing current DB content")
    if not logger.level == logger.DEBUG:
        return
    else:
        console = Console()
        db = sqlite3.connect(SET_PORTS_DB)
        cursor = db.cursor()
        cursor.execute("SELECT service, port FROM Ports")
        results = cursor.fetchall()
        db.close()
        if results:
            table = Table()
            table.add_column("Service", style="cyan")
            table.add_column("Port", style="magenta")
            for result in results:
                table.add_row(result[0], str(result[1]))
            console.print(table)
        else:
            console.print("No data found in the Ports table.", style="red bold")


def db_read(service):
    db = sqlite3.connect(SET_PORTS_DB)
    cursor = db.cursor()
    cursor.execute("SELECT port FROM Ports WHERE service = ?", (service,))
    result = cursor.fetchone()  # Assuming you expect only one result
    db.close()
    display_ports_table()
    if result:
        return result[0]  # Extract the port value from the result
    else:
        return None  # Return None if the service is not found in the database


def db_write(service, port):
    db = sqlite3.connect(SET_PORTS_DB)
    db.execute("INSERT OR REPLACE INTO Ports (service, port) VALUES (?, ?)", (service, port))
    db.commit()
    db.close()
    display_ports_table()


def ports_already_set():
    db = sqlite3.connect(SET_PORTS_DB)
    cursor = db.cursor()
    cursor.execute("SELECT port FROM Ports")
    results = cursor.fetchall()
    db.close()

    return [result[0] for result in results] if results else []

    # Following code used to generate a list from a dict similar to the DEFAULT_PORT, in case we want the
    #  exclusing list to include the default ports, whether they are set or not
    # from typing import Iterable
    #
    # if isinstance(d, dict):
    #     for v in d.values():
    #         yield from ports_already_set(v)
    # elif isinstance(d, Iterable) and not isinstance(d, str):  # or list, set, ... only
    #     for v in d:
    #         yield from ports_already_set(v)
    # else:
    #     yield d


def find_available_port():
    if os.environ.get('EXEGOL_RANDOMIZE_SERVICE_PORTS') == "true":
        logger.debug("EXEGOL_RANDOMIZE_SERVICE_PORTS is True")
        excluded_ports = list(ports_already_set())
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

    ports = {}
    logger.verbose("Finding ports (random or default)")
    ports["bolt"] = find_available_port() or DEFAULT_PORT["neo4"]["bolt"]
    logger.debug(f'Port for neo4j (bolt): {ports["bolt"]}')
    ports["http"] = find_available_port() or DEFAULT_PORT["neo4"]["http"]
    logger.debug(f'Port for neo4j (http): {ports["http"]}')
    ports["https"] = find_available_port() or DEFAULT_PORT["neo4"]["https"]
    logger.debug(f'Port for neo4j (https): {ports["https"]}')
    logger.verbose(f"Ports found: {ports}")

    logger.verbose("Editing config files")
    logger.verbose("Reading config file")
    with open(CONFIG["neo4j"], 'r') as neo4j_config:
        neo4j_conf = neo4j_config.readlines()

    logger.verbose("Creating new config lines")
    for i, line in enumerate(neo4j_conf):
        if "dbms.connector.bolt.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.bolt.listen_address=:{ports["bolt"]}\n'
            logger.debug(neo4j_conf[i].strip())
        elif "dbms.connector.http.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.http.listen_address=:{ports["http"]}\n'
            logger.debug(neo4j_conf[i].strip())
        elif "dbms.connector.https.listen_address=" in line.strip():
            neo4j_conf[i] = f'dbms.connector.https.listen_address=:{ports["https"]}\n'
            logger.debug(neo4j_conf[i].strip())

    logger.verbose("Editing config files")
    logger.verbose("Writing config to file")
    with open(CONFIG["neo4j"], 'w') as neo4j_config:
        neo4j_config.writelines(neo4j_conf)

    # Updating tools that rely on neo4j: BloodHound

    logger.info("Updating BloodHound config")
    with open(CONFIG["bloodhound"], 'r') as bloodhound_config:
        logger.verbose("Loading current config")
        bloodhound_conf = json.load(bloodhound_config)

    logger.verbose("Creating new config")
    bloodhound_conf['databaseInfo']['url'] = f"bolt://localhost:{ports['bolt']}"
    logger.debug(f"databaseInfo['url']: {bloodhound_conf['databaseInfo']['url']}")

    logger.verbose("Writing config to file")
    with open(CONFIG["bloodhound"], 'w') as bloodhound_config:
        json.dump(bloodhound_conf, bloodhound_config, indent=4)

    logger.verbose("Exporting ports to DB")
    db_write("neo4j_bolt", ports["bolt"])
    db_write("neo4j_http", ports["http"])
    db_write("neo4j_https", ports["https"])

    logger.success(f"Set port {db_read('neo4j_bolt')}")


def trilium():
    logger.info("Setting port for trilium")

    ports = {"trilium": find_available_port() or DEFAULT_PORT["trilium"]}
    logger.verbose(f"Ports found: {ports['trilium']}")

    logger.verbose("Reading config file")
    with open(CONFIG["trilium"], 'r') as trilium_config:
        trilium_conf = trilium_config.readlines()

    logger.verbose("Creating new config lines")
    for i, line in enumerate(trilium_conf):
        if line.startswith('port='):
            trilium_conf[i] = f'port={ports["trilium"]}\n'
            logger.debug(trilium_conf[i].strip())

    logger.verbose("Writing config to file")
    with open(CONFIG["trilium"], 'w') as trilium_config:
        trilium_config.writelines(trilium_conf)

    logger.verbose("Exporting ports to DB")
    db_write("trilium", ports["trilium"])

    logger.success(f"Set port {db_read('trilium')}")


def burp():
    logger.info("Setting port for Burp Suite")

    ports = {"burp": find_available_port() or DEFAULT_PORT["burp"]}
    logger.verbose(f"Ports found: {ports['burp']}")

    logger.info("Updating burp config")
    with open(CONFIG["burp"], 'r') as burp_config:
        logger.verbose("Loading current config")
        burp_conf = json.load(burp_config)

    logger.verbose("Creating new config")
    logger.debug(burp_conf)
    if len(burp_conf['proxy']['request_listeners']) > 1:
        logger.warning("More than one request listener, something may be wrong")
    burp_conf['proxy']['request_listeners'][0]['listener_port'] = ports["burp"]
    logger.debug(
        f"proxy['request_listeners']['listener_port']: {burp_conf['proxy']['request_listeners'][0]['listener_port']}")

    logger.verbose("Writing config to file")
    with open(CONFIG["burp"], 'w') as burp_config:
        json.dump(burp_conf, burp_config, indent=4)

    logger.verbose("Exporting ports to DB")
    db_write("burp", ports["burp"])

    logger.success(f"Set port {db_read('burp')}")


def parse_args():
    parser = argparse.ArgumentParser(add_help=True, description='Exegol services and ports manager')
    parser.add_argument("-a", "--action", choices=['get', 'set'], nargs='?', default='get',
                        help='Either set service ports when starting it, or get the ports currently in use')
    parser.add_argument("-s", "--service", choices=SERVICES, nargs='?', help="Target service")
    parser.add_argument("-v", "--verbose", dest="verbosity", action="count", default=0, help="verbosity level")
    parser.add_argument("-q", "--quiet", dest="quiet", action="store_true", default=False,
                        help="show no information at all")
    # if len(sys.argv) == 1:
    #     parser.print_help()
    #     sys.exit(1)
    _args = parser.parse_args()
    if _args.action == "get" and _args.service is None:
        parser.error("A service must be supplied when the 'get' action is used")
    return parser.parse_args()


def main():
    # init db
    # using db instead of reading ports from config files so that the db can be read
    db = sqlite3.connect(SET_PORTS_DB)
    db.execute("CREATE TABLE IF NOT EXISTS Ports (service VARCHAR PRIMARY KEY, port INTEGER)")
    db.close()
    display_ports_table()
    if args.action == "get":
        logger.verbose(f"Getting port for service {args.service}")
        real_service = args.service if not args.service == "neo4j" else "neo4j_bolt"
        port = db_read(real_service)
        logger.debug(f"Port for service {real_service}: {port}")
        print(port)
    elif args.action == "set":
        logger.verbose(f"Setting port{'for service' + args.service if args.service is not None else ''}")
        if args.service is None:
            logger.debug("No target service supplied. Returning an available port")
            a = find_available_port()
            logger.verbose(f"Port found: {a}")
            print(a)
        else:
            if args.service == "neo4j":
                neo4j()
            elif args.service == "trilium":
                trilium()
            elif args.service == "burp":
                burp()
            else:
                print("Service not supported")


if __name__ == "__main__":
    args = parse_args()
    logger.setVerbosity(verbose_level=args.verbosity, quiet=args.quiet)  # Set DEBUG level
    main()
