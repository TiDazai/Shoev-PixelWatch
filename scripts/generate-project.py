from pathlib import Path
import hashlib
r=Path(__file__).resolve().parents[1]
# Xcode project with an application and hosted XCTest target, no generator dependency.
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects={}
def obj(name,body): objects[uid(name)]=body;return uid(name)
def q(s):return '"'+s.replace('"','\\"')+'"'
appFiles=sorted(r.glob('PixelWatch/**/*.swift'))
testFiles=sorted(r.glob('Tests/**/*.swift'))
# tests are added by the companion generator after files exist
fileIDs=[]; buildIDs=[]
for p in appFiles:
 path=str(p.relative_to(r)); f=obj('file:'+path,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = SOURCE_ROOT;');fileIDs.append(f)
 buildIDs.append(obj('build:'+path,f'isa = PBXBuildFile; fileRef = {f};'))
res='PixelWatch/Resources/Localizable.xcstrings';f=obj('file:'+res,f'isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = {q(res)}; sourceTree = SOURCE_ROOT;');fileIDs.append(f);resBuild=obj('build:'+res,f'isa = PBXBuildFile; fileRef = {f};')
icon='PixelWatch/Resources/PixelWatch.icns';f=obj('file:'+icon,f'isa = PBXFileReference; lastKnownFileType = image.icns; path = {q(icon)}; sourceTree = SOURCE_ROOT;');fileIDs.append(f);iconBuild=obj('build:'+icon,f'isa = PBXBuildFile; fileRef = {f};')
license='PixelWatch/Resources/LICENSE.txt';f=obj('file:'+license,f'isa = PBXFileReference; lastKnownFileType = text; path = {q(license)}; sourceTree = SOURCE_ROOT;');fileIDs.append(f);licenseBuild=obj('build:'+license,f'isa = PBXBuildFile; fileRef = {f};')
extraResourceBuilds=[]
for resource in ['Translations.json', 'BrandMark.png']:
 path='PixelWatch/Resources/'+resource;kind='image.png' if resource.endswith('.png') else 'text.json';f=obj('file:'+path,f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(path)}; sourceTree = SOURCE_ROOT;');fileIDs.append(f);extraResourceBuilds.append(obj('build:'+path,f'isa = PBXBuildFile; fileRef = {f};'))
permissionFiles=[]
for language in ['en','ru']:
 path='PixelWatch/Resources/'+language+'.lproj/InfoPlist.strings';f=obj('file:'+path,f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {language}; path = {q(path)}; sourceTree = SOURCE_ROOT;');permissionFiles.append(f)
permissionGroup=obj('permissionVariant',f'isa = PBXVariantGroup; children = { "(" + ", ".join(permissionFiles) + ")" }; name = InfoPlist.strings; sourceTree = "<group>";')
fileIDs.append(permissionGroup);extraResourceBuilds.append(obj('permissionBuild',f'isa = PBXBuildFile; fileRef = {permissionGroup};'))
appProduct=obj('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = "SHOEV PixelWatch.app"; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PixelWatchTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
def arr(items):return '('+', '.join(items)+')'
appSources=obj('appSources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(buildIDs)}; runOnlyForDeploymentPostprocessing = 0;')
resources=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resBuild}, {iconBuild}, {licenseBuild}, {", ".join(extraResourceBuilds)}); runOnlyForDeploymentPostprocessing = 0;')
frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
testFileIDs=[];testBuildIDs=[]
for p in testFiles:
 path=str(p.relative_to(r));f=obj('file:'+path,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = SOURCE_ROOT;');testFileIDs.append(f);testBuildIDs.append(obj('build:'+path,f'isa = PBXBuildFile; fileRef = {f};'))
testSources=obj('testSources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(testBuildIDs)}; runOnlyForDeploymentPostprocessing = 0;')
testFrameworks=obj('testFrameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
products=obj('products',f'isa = PBXGroup; name = Products; children = ({appProduct}, {testProduct}); sourceTree = "<group>";')
sourcesGroup=obj('sourcesGroup',f'isa = PBXGroup; name = PixelWatch; children = {arr(fileIDs)}; sourceTree = "<group>";')
testsGroup=obj('testsGroup',f'isa = PBXGroup; name = Tests; children = {arr(testFileIDs)}; sourceTree = "<group>";')
mainGroup=obj('mainGroup',f'isa = PBXGroup; children = ({sourcesGroup},{testsGroup},{products}); sourceTree = "<group>";')
projectID=uid('project');appID=uid('app');testID=uid('test')
proxy=obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {projectID}; proxyType = 1; remoteGlobalIDString = {appID}; remoteInfo = PixelWatch;')
dep=obj('dependency',f'isa = PBXTargetDependency; target = {appID}; targetProxy = {proxy};')
def configs(prefix, extra):
 ids=[]
 for name in ['Debug','Release']:
  base='MACOSX_DEPLOYMENT_TARGET = 26.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; SWIFT_STRICT_CONCURRENCY = complete; '
  base+= 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if name=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
  ids.append(obj(prefix+name,f'isa = XCBuildConfiguration; buildSettings = {{ {base} {extra} }}; name = {name};'))
 return obj(prefix+'configlist',f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
projectConfig=configs('project','')
appConfig=configs('app','PRODUCT_NAME = "SHOEV PixelWatch"; PRODUCT_MODULE_NAME = PixelWatch; PRODUCT_BUNDLE_IDENTIFIER = systems.shoev.pixelwatch; INFOPLIST_FILE = PixelWatch/Resources/Info.plist; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_HARDENED_RUNTIME = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks"; COMBINE_HIDPI_IMAGES = YES;')
testConfig=configs('test','PRODUCT_NAME = PixelWatchTests; PRODUCT_BUNDLE_IDENTIFIER = systems.shoev.pixelwatch.tests; GENERATE_INFOPLIST_FILE = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SHOEV PixelWatch.app/Contents/MacOS/SHOEV PixelWatch"; BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_IDENTITY = "-"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";')
obj('app',f'isa = PBXNativeTarget; buildConfigurationList = {appConfig}; buildPhases = ({appSources},{frameworks},{resources}); buildRules = (); dependencies = (); name = PixelWatch; productName = "SHOEV PixelWatch"; productReference = {appProduct}; productType = "com.apple.product-type.application";')
obj('test',f'isa = PBXNativeTarget; buildConfigurationList = {testConfig}; buildPhases = ({testSources},{testFrameworks}); buildRules = (); dependencies = ({dep}); name = PixelWatchTests; productName = PixelWatchTests; productReference = {testProduct}; productType = "com.apple.product-type.bundle.unit-test";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2630; TargetAttributes = {{ {testID} = {{ TestTargetID = {appID}; }}; }}; }}; buildConfigurationList = {projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base, ru); mainGroup = {mainGroup}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({appID},{testID});')
x=r/'PixelWatch.xcodeproj';(x/'xcshareddata/xcschemes').mkdir(parents=True,exist_ok=True)
(x/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(f'{k} = {{ {v} }};' for k,v in objects.items())+f'\n}}; rootObject = {projectID}; }}\n')
ref=lambda ident,name:f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{name}" BlueprintName="{ "PixelWatch" if ident==appID else "PixelWatchTests"}" ReferencedContainer="container:PixelWatch.xcodeproj"/>'
(x/'xcshareddata/xcschemes/PixelWatch.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(appID,'SHOEV PixelWatch.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><Testables><TestableReference skipped="NO">{ref(testID,'PixelWatchTests.xctest')}</TestableReference></Testables><EnvironmentVariables><EnvironmentVariable key="PIXELWATCH_TESTING" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(appID,'SHOEV PixelWatch.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(appID,'SHOEV PixelWatch.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
