
import sys
import requests
from bs4 import BeautifulSoup
import re

## NOT READY ###

def search_artifact_versions_with_aarch64(group_id, artifact_id):
    base_url = "https://mvnrepository.com"
    search_url = f"{base_url}/{group_id}/{artifact_id}"
    
    response = requests.get(search_url)
    soup = BeautifulSoup(response.content, 'html.parser')
    print(f"soup: {soup}")
    
    artifact_link = soup.find('a', href=re.compile(f"/{group_id}/{artifact_id}$"))
    
    if not artifact_link:
        print(f"Artifact {group_id}:{artifact_id} not found.")
        return
    
    artifact_url = base_url + artifact_link['href']
    response = requests.get(artifact_url)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    version_links = soup.find_all('a', href=re.compile(f"/{group_id}/{artifact_id}/"))
    
    results = []
    
    for link in version_links:
        version_number = link.text.strip()
        version_url = base_url + link['href']
        response = requests.get(version_url)
        soup = BeautifulSoup(response.content, 'html.parser')
        
        files = soup.find_all('tr', class_='vbtn')
        for file in files:
            file_name = file.find('a').text
            if file_name.endswith('.jar'):
                jar_url = base_url + file.find('a')['href']
                response = requests.get(jar_url)
                soup = BeautifulSoup(response.content, 'html.parser')
                
                native_folder = soup.find('a', text='native/')
                if native_folder:
                    native_url = base_url + native_folder['href']
                    response = requests.get(native_url)
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    aarch64_folder = soup.find('a', text='aarch64/')
                    if aarch64_folder:
                        aarch64_url = base_url + aarch64_folder['href']
                        response = requests.get(aarch64_url)
                        soup = BeautifulSoup(response.content, 'html.parser')
                        
                        aarch64_files = [a.text for a in soup.find_all('a') if a.text.endswith('.so')]
                        if aarch64_files:
                            results.append((version_number, aarch64_files))
                        break
    
    if results:
        print(f"Versions of {group_id}:{artifact_id} containing aarch64 native files:")
        for version, files in results:
            print(f"Version: {version}")
            print("aarch64 files:")
            for file in files:
                print(f"  - {file}")
            print()
    else:
        print(f"No versions of {group_id}:{artifact_id} contain aarch64 native files.")

# 使用示例
# search_artifact_versions_with_aarch64("org.lwjgl", "lwjgl")


def main():
    if len(sys.argv) != 3:
        print("使用方法: python list_mvn_releases.py <group_id> <artifact_id>")
        sys.exit(1)
    
    group_id = sys.argv[1]
    artifact_id = sys.argv[2]
    search_artifact_versions_with_aarch64(group_id, artifact_id)

if __name__ == "__main__":
    main()

    