import sys
import requests

def get_releases(project_name):
    """获取指定PyPI项目的所有发布版本信息"""
    url = f"https://pypi.org/pypi/{project_name}/json"
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()['releases']
    else:
        print(f"无法获取项目信息: {response.status_code}")
        return None

def list_files(releases):
    """列出所有可下载的文件名"""
    for release in releases:
        for file_info in releases[release]:
            print(file_info['filename'])

def main():
    if len(sys.argv) != 2:
        print("使用方法: python list_pypi_releases.py <project_name>")
        sys.exit(1)
    
    project_name = sys.argv[1]
    releases = get_releases(project_name)
    if releases:
        list_files(releases)

if __name__ == "__main__":
    main()

    
    