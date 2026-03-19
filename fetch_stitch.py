import urllib.request
import os

os.makedirs('StitchDesigns', exist_ok=True)

files = [
    ("RecordingScreen.html", "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzczYTM1ZTBkZjZjNzRlNzdiY2Y0MTliMjQ0NGIzZDhiEgsSBxCmgIqWug0YAZIBJAoKcHJvamVjdF9pZBIWQhQxMTkyNzU3Nzc2MDczODc4OTE0MA&filename=&opi=89354086"),
    ("ScriptLibrary.html", "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sX2QwNDJmMGY2YTUyYjRjYmRhOTlhOGFkYmFhMTYxYjdiEgsSBxCmgIqWug0YAZIBJAoKcHJvamVjdF9pZBIWQhQxMTkyNzU3Nzc2MDczODc4OTE0MA&filename=&opi=89354086"),
    ("ScriptEditor.html", "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sX2MzY2FhMzFkYTMzNTRmMGI4ZDkzMGRhN2ZmZjZmYjBhEgsSBxCmgIqWug0YAZIBJAoKcHJvamVjdF9pZBIWQhQxMTkyNzU3Nzc2MDczODc4OTE0MA&filename=&opi=89354086"),
    ("RecordingGallery.html", "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzkxMmQ3NzdkYWVmMjRjM2I5N2U5ZDc1NmVkNTEwMDBjEgsSBxCmgIqWug0YAZIBJAoKcHJvamVjdF9pZBIWQhQxMTkyNzU3Nzc2MDczODc4OTE0MA&filename=&opi=89354086"),
    ("Settings.html", "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzIzMDkwZDhjYTJhMjRiY2JiNzA5MDc1OTNlMjAyZDM0EgsSBxCmgIqWug0YAZIBJAoKcHJvamVjdF9pZBIWQhQxMTkyNzU3Nzc2MDczODc4OTE0MA&filename=&opi=89354086")
]

for filename, url in files:
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            with open(f"StitchDesigns/{filename}", "wb") as f:
                f.write(response.read())
        print(f"Downloaded {filename}")
    except Exception as e:
        print(f"Failed to download {filename}: {e}")
