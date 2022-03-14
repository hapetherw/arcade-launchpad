import fs from "fs";

async function load(name: string) {
  try {
    const data = await fs.readFileSync(`${process.cwd()}/addresses/${name}.json`)
    return JSON.parse(data.toString())
  } catch (e) {
    console.log(e)
    return null
  }
}

async function save(name: string, content: any) {
    const sharedAddressPath = `${process.cwd()}/addresses/${name}.json`
    await fs.writeFileSync(sharedAddressPath, JSON.stringify(content, null, 2))
}

export { load, save }