import base64, json, os, sys, urllib.request, pathlib
# Генерация текстуры через Nano Banana на OpenRouter.
# python3 tools/gen.py "<промпт>" out.png 3:2 4K   (ключ в OPENROUTER_API_KEY)
KEY = os.environ['OPENROUTER_API_KEY'].strip().strip('"')
def gen(prompt, out, model="google/gemini-3.1-flash-image", ratio="3:2", size="4K"):
    body = {"model":model,"modalities":["image","text"],
            "image_config":{"aspect_ratio":ratio,"image_size":size},
            "messages":[{"role":"user","content":[{"type":"text","text":prompt}]}]}
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Content-Type":"application/json","Authorization":"Bearer "+KEY})
    r = json.load(urllib.request.urlopen(req, timeout=400))
    ims = r["choices"][0]["message"].get("images") or []
    if not ims: print(json.dumps(r, ensure_ascii=False)[:1500]); return
    pathlib.Path(out).write_bytes(base64.b64decode(ims[0]["image_url"]["url"].split(",",1)[1]))
    print("saved", out, r.get("usage",{}).get("cost"))
if __name__ == "__main__":
    gen(sys.argv[1], sys.argv[2], ratio=sys.argv[3], size=sys.argv[4] if len(sys.argv)>4 else "4K")
