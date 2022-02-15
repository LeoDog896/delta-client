import Foundation
import ZIPFoundation
import ZippyJSON

enum ResourcePackError: LocalizedError {
  /// The specified resource pack directory does not exist.
  case noSuchDirectory
  /// The resource pack's `pack.mcmeta` is invalid.
  case failedToReadMCMeta(Error)
  /// Failed to list the contents of a texture directory.
  case failedToEnumerateTextures(Error)
  /// Failed to figure out what namespaces are included in this resource pack.
  case failedToEnumerateNamespaces
  /// Failed to convert an image into a texture.
  case failedToLoadTexture(Identifier, Error)
  /// Failed to read the image for the given texture from a file.
  case failedToReadTextureImage
  /// Failed to create a `CGDataProvider` for the given image file.
  case failedToCreateImageProvider
  /// Failed to download the specified client jar.
  case clientJarDownloadFailure
  /// Failed to extract assets from a client jar.
  case clientJarExtractionFailure
  /// Failed to copy the vanilla assets from the extracted client jar.
  case assetCopyFailure
  /// Failed to create a dummy pack.mcmeta for the downloaded vanilla assets.
  case failedToCreatePackMCMetaData
  /// No client jar is available to download for the specified version.
  case noURLForVersion(String)
  /// Failed to decode a version manifest.
  case versionManifestFailure(Error)
  /// Failed to decode the versions manifest.
  case versionsManifestFailure(Error)
}

public struct ResourcePack {
  /// The metadata of this resource pack.
  public var metadata: PackMCMeta.Metadata
  /// The metadata of languages contained within this resource pack.
  public var languages: [String: PackMCMeta.Language]
  /// All resources contained in this resource pack, keyed by namespace.
  public var resources: [String: Resources]
  
  /// Resources in the 'minecraft' namespace.
  public var vanillaResources: Resources {
    resources["minecraft"] ?? Resources()
  }
  
  // MARK: Access
  
  public func getBlockModel(for stateId: Int, at position: Position) -> BlockModel? {
    return vanillaResources.blockModelPalette.model(for: stateId, at: position)
  }
  
  public func getBlockTexturePalette() -> TexturePalette {
    return vanillaResources.blockTexturePalette
  }
  
  public func getDefaultLocale() -> MinecraftLocale {
    return vanillaResources.locales[Constants.locale] ?? MinecraftLocale()
  }
  
  // MARK: Loading
  
  /// Loads the resource pack in the given directory. If provided, cached resources are loaded from the given cache directory if present. To create a resource pack cache use ``cache(to:)``. Resource pack caches do not cache the whole pack yet, only the most resource intensive parts to load.
  ///
  /// ``RegistryStore/shared`` must be populated for this to work.
  public static func load(from directory: URL, cacheDirectory: URL?) throws -> ResourcePack {
    // Check resource pack exists
    guard FileManager.default.directoryExists(at: directory) else {
      throw ResourcePackError.noSuchDirectory
    }
    
    // Read pack.mcmeta
    let mcMetaFile = directory.appendingPathComponent("pack.mcmeta")
    let mcMeta = try readPackMCMeta(at: mcMetaFile)
    
    // Read resources from present namespaces
    guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) else {
      throw ResourcePackError.failedToEnumerateNamespaces
    }
    
    var namespacedResources: [String: ResourcePack.Resources] = [:]
    for directory in contents where FileManager.default.directoryExists(at: directory) {
      let namespace = directory.lastPathComponent
      let resources = try loadResources(from: directory, inNamespace: namespace, cacheDirectory: cacheDirectory?.appendingPathComponent(namespace))
      namespacedResources[namespace] = resources
    }
    
    // Create pack
    return ResourcePack(
      metadata: mcMeta.metadata,
      languages: mcMeta.languages ?? [:],
      resources: namespacedResources)
  }
  
  /// Loads the resources in the given directory and gives them the specified namespace.
  public static func loadResources(
    from directory: URL,
    inNamespace namespace: String,
    cacheDirectory: URL?
  ) throws -> ResourcePack.Resources {
    log.debug("Loading resources from '\(namespace)' namespace")
    var resources = Resources()
    
    // Load textures if the pack contains any
    log.debug("Loading textures")
    let textureDirectory = directory.appendingPathComponent("textures")
    if FileManager.default.directoryExists(at: textureDirectory) {
      // Load block textures if pack contains any
      let blockTextureDirectory = textureDirectory.appendingPathComponent("block")
      if FileManager.default.directoryExists(at: blockTextureDirectory) {
        resources.blockTexturePalette = try TexturePalette.load(from: blockTextureDirectory, inNamespace: namespace, withType: "block")
      }
    }
    
    // Load biome colors
    log.debug("Loading biome colors")
    let colorMapDirectory = textureDirectory.appendingPathComponent("colormap")
    if FileManager.default.directoryExists(at: colorMapDirectory) {
      let biomeColors = try BiomeColors(from: colorMapDirectory)
      resources.biomeColors = biomeColors
    }
    
    // Attempt to load block model palette from the resource pack cache if it exists
    var loadedFromCache = false
    if let cacheDirectory = cacheDirectory {
      let modelCacheFile = cacheDirectory.appendingPathComponent("block_models.bin")
      log.debug("Loading cached block models")
      if FileManager.default.fileExists(atPath: modelCacheFile.path) {
        do {
          resources.blockModelPalette = try BlockModelPalette(fromFile: modelCacheFile)
          loadedFromCache = true
        } catch {
          log.warning("Failed to load block models from cache, deleting cache")
          do {
            try FileManager.default.removeItem(at: cacheDirectory)
          } catch {
            log.warning("Failed to remove invalid block model cache, ignoring anyway")
          }
        }
      }
    }
    
    // Load models if present and not loaded from cache
    if !loadedFromCache {
      log.debug("Loading block models from resourcepack")
      let modelDirectory = directory.appendingPathComponent("models")
      if FileManager.default.directoryExists(at: modelDirectory) {
        // Load block models if present
        let blockModelDirectory = modelDirectory.appendingPathComponent("block")
        if FileManager.default.directoryExists(at: blockModelDirectory) {
          // Load block models
          resources.blockModelPalette = try BlockModelPalette.load(
            from: blockModelDirectory,
            namespace: namespace,
            blockTexturePalette: resources.blockTexturePalette)
        }
      }
    }
    
    // Load locales if present
    let localeDirectory = directory.appendingPathComponent("lang")
    if FileManager.default.directoryExists(at: localeDirectory) {
      let contents = try FileManager.default.contentsOfDirectory(at: localeDirectory, includingPropertiesForKeys: nil, options: [])
      for file in contents where file.pathExtension == "json" {
        let locale = try MinecraftLocale(localeFile: file)
        resources.locales[file.deletingPathExtension().lastPathComponent] = locale
      }
    }
    
    return resources
  }
  
  /// Reads a pack.mcmeta file.
  public static func readPackMCMeta(at mcMetaFile: URL) throws -> ResourcePack.PackMCMeta {
    let mcMeta: ResourcePack.PackMCMeta
    do {
      let data = try Data(contentsOf: mcMetaFile)
      mcMeta = try ZippyJSONDecoder().decode(ResourcePack.PackMCMeta.self, from: data)
    } catch {
      throw ResourcePackError.failedToReadMCMeta(error)
    }
    
    return mcMeta
  }
  
  // MARK: Caching
  
  /// Caches the parts of the pack that are most resource intensive to process (such as block models).
  public func cache(to directory: URL) throws {
    for (namespace, resources) in resources {
      log.debug("Caching resources from '\(namespace)' namespace")
      let cacheDirectory = directory.appendingPathComponent(namespace)
      try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
      
      // Cache block models
      let blockModelCacheFile = cacheDirectory.appendingPathComponent("block_models.bin")
      try resources.blockModelPalette.cache(toFile: blockModelCacheFile)
    }
  }
  
  // MARK: Download
  
  /// Tasks to be exectued during the `downloadVanillaAssets` process
  private enum DownloadStep: CaseIterable, TaskStep {
    case fetchManifest, downloadJar, extractJar, copyingAssets, creatingMcmeta
    
    public var relativeDuration: Double { 1 }
    
    public var message: String {
      switch self {
        case .fetchManifest: return "Fetching version manifest"
        case .downloadJar: return "Downloading client jar"
        case .extractJar: return "Extracting client jar"
        case .copyingAssets: return "Copying assets"
        case .creatingMcmeta: return "Creating pack.mcmeta"
      }
    }
  }
  
  /// Downloads the vanilla client and extracts its assets (textures, block models, etc.).
  public static func downloadVanillaAssets(forVersion version: String, to directory: URL, _ onProgress: ((Double, String) -> Void)?) throws {
    var progress = TaskProgress<DownloadStep>()
    
    func updateProgressStatus(step: DownloadStep) {
      progress.update(to: step)
      log.info(progress.message)
      onProgress?(progress.progress, progress.message)
    }
    // Get the url for the client jar
    updateProgressStatus(step: .fetchManifest)
    let versionManifest = try getVersionManifest(for: version)
    let clientJarURL = versionManifest.downloads.client.url
    
    // Download the client jar
    updateProgressStatus(step: .downloadJar)
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let clientJarTempFile = temporaryDirectory.appendingPathComponent("client.jar")
    do {
      let data = try Data(contentsOf: clientJarURL)
      try data.write(to: clientJarTempFile)
    } catch {
      log.error("Failed to download client jar: \(error)")
      throw ResourcePackError.clientJarDownloadFailure
    }
    
    // Extract the contents of the client jar (jar files are just zip archives)
    updateProgressStatus(step: .extractJar)
    let extractedClientJarDirectory = temporaryDirectory.appendingPathComponent("client", isDirectory: true)
    try? FileManager.default.removeItem(at: extractedClientJarDirectory)
    do {
      try FileManager.default.unzipItem(at: clientJarTempFile, to: extractedClientJarDirectory, skipCRC32: true)
    } catch {
      log.error("Failed to extract client jar: \(error)")
      throw ResourcePackError.clientJarExtractionFailure
    }
    
    // Copy the assets from the extracted client jar to application support
    updateProgressStatus(step: .copyingAssets)
    do {
      try FileManager.default.copyItem(
        at: extractedClientJarDirectory.appendingPathComponent("assets"),
        to: directory)
    } catch {
      log.error("Failed to copy assets from extracted client jar: \(error)")
      throw ResourcePackError.assetCopyFailure
    }
    
    // Create a default pack.mcmeta for it
    updateProgressStatus(step: .creatingMcmeta)
    let contents = #"{"pack": {"pack_format": 5, "description": "The default vanilla assets"}}"#
    guard let data = contents.data(using: .utf8) else {
      throw ResourcePackError.failedToCreatePackMCMetaData
    }
    
    do {
      try data.write(to: directory.appendingPathComponent("pack.mcmeta"))
    } catch {
      log.error("Failed to write pack.mcmeta file to vanilla assets")
    }
  }
  
  /// Get the manifest describing all versions.
  private static func getVersionsManifest() throws -> VersionsManifest {
    // swiftlint:disable force_unwrap
    let versionsManifestURL = URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")!
    // swiftlint:enable force_unwrap
    
    let versionsManifest: VersionsManifest
    do {
      let data = try Data(contentsOf: versionsManifestURL)
      versionsManifest = try ZippyJSONDecoder().decode(VersionsManifest.self, from: data)
    } catch {
      throw ResourcePackError.versionsManifestFailure(error)
    }
    
    return versionsManifest
  }
  
  /// Get the manifest for the specified version.
  private static func getVersionManifest(for versionString: String) throws -> VersionManifest {
    let versionURLs = try getVersionURLs()
    
    guard let versionURL = versionURLs[versionString] else {
      log.error("Failed to find manifest download url for version \(versionString)")
      throw ResourcePackError.noURLForVersion(versionString)
    }
    
    let versionManifest: VersionManifest
    do {
      let data = try Data(contentsOf: versionURL)
      versionManifest = try ZippyJSONDecoder().decode(VersionManifest.self, from: data)
    } catch {
      throw ResourcePackError.versionManifestFailure(error)
    }
    
    return versionManifest
  }
  
  /// Returns a map from version name to the version's manifest url.
  private static func getVersionURLs() throws -> [String: URL] {
    let manifest = try getVersionsManifest()
    var urls: [String: URL] = [:]
    for version in manifest.versions {
      urls[version.id] = version.url
    }
    return urls
  }
}