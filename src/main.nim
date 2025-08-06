import std/[asyncdispatch, httpclient]
import strformat
import json, strutils, sets

proc ask(prompt: string): string =
  stdout.writeLine prompt
  return stdin.readLine().strip()

proc downloadUrl(url: string, retries: int): Future[string] {.async.} =
  var client = newAsyncHttpClient()
  defer:
    client.close()
  var tries = 0
  var resp: AsyncResponse
  while tries < retries:
    tries.inc()
    resp = await client.get(url)
    if resp.code.is5xx:
      continue
    if resp.code.is4xx:
      echo "client error"
      return
    return await resp.bodyStream.readAll()

proc downloadCrts(domain: string): Future[string] {.async.} =
  var url = fmt"https://crt.sh/?q=%25.{domain}&output=json"
  echo "downloading ", url
  return await downloadUrl(url, 4)

var domain = ask("Enter domain: ")
echo "Subdomains of domain : ", domain
let crts = waitFor downloadCrts(domain)
echo "finished downloading"

var dnsSet = initHashSet[string]()

let js = parseJson(crts)
for entry in js:
  for possible_subdomain in splitLines(entry["name_value"].getStr()):
    if possible_subdomain.startsWith("*"):
      continue
    if possible_subdomain.startsWith("www."):
      continue
    if possible_subdomain == domain:
      continue
    if possible_subdomain.endsWith("." & domain):
      dnsSet.incl(possible_subdomain)

echo "Found ", dnsSet.len(), " subdomains"
if dnsSet.len() == 0:
  quit("Found no subdomains", QuitSuccess)
for entry in dnsSet:
  echo entry

import os

## cache results
proc saveResults() =
  var resultFile = ask("save results to file (n to skip): ")
  if fileExists(resultFile):
    echo "file already exists, choose another file"
    saveResults()
    return
  if resultFile.toLower() == "n":
    return
  if resultFile.isEmptyOrWhitespace():
    return
  var file: File
  if not file.open(resultFile, fmWrite):
    echo "failed to open said file, choose another file"
    saveResults()
    return
  echo "opened file ", resultFile
  for entry in dnsSet:
    writeLine(file, entry)
  file.close()
  echo "saved file ", resultFile

saveResults()
