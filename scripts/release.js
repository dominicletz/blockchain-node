const octokit = require('@octokit/rest')()
const fs = require('fs')

const owner = 'helium'
const repo = 'blockchain-node'
const per_page = 100

octokit.authenticate({
  type: 'token',
  token: process.env.GH_TOKEN
})

async function run() {
  const release = await fetchRelease()
  await uploadAssets(release)
}

async function fetchRelease() {
  return new Promise((resolve, reject) => {
    octokit.repos.getReleases({ owner, repo, per_page }).then(({ data, headers, status }) => {
      const tagName = `v${getVersion()}`
      const release = data.filter(d => d.draft).find(d => d.tag_name === tagName)

      if (release) {
        resolve(release)
      } else {
        reject(new Error(`Couldn't find draft release with tag_name: ${tagName}`))
      }
    })
  })
}

async function uploadAssets(release) {
  return new Promise((resolve) => {
    fs.readdir('../latest/', (err, files) => {
      if (err) throw err
      Promise.all(
        files.map(filename => uploadAsset(release, filename))
      ).then(() => resolve())
    })
  })
}

async function uploadAsset(release, name) {
  const file = await readFile(`../latest/${name}`)
  const existingAsset = release.assets.find(a => a.name === name)
  if (existingAsset) {
    console.log('deleting existing asset...')
    await deleteAsset(existingAsset.id)
  }

  return new Promise(resolve => {
    console.log(`uploading ${name}...`)
    octokit.repos.uploadAsset({
      url: release.upload_url,
      headers: {
        'content-length': file.toString().length,
        'content-type': 'application/gzip',
      },
      name,
      file
    }).then(result => { resolve() })
  })
}

async function readFile(path) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, (err, data) => {
      if (err) reject(err)
      resolve(data)
    })
  })
}

async function deleteAsset(asset_id) {
  return new Promise(resolve => {
    octokit.repos.deleteAsset({
      owner,
      repo,
      asset_id
    }).then(resolve())
  })
}

const getVersion = () => (
  fs.readFileSync('../VERSION').toString().trim()
)

run()
