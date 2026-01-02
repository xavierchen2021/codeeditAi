//
//  Persistence.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import CoreData
import os.log

struct PersistenceController {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "win.aiX.app", category: "Persistence")
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample workspaces
        let personalWorkspace = Workspace(context: viewContext)
        personalWorkspace.id = UUID()
        personalWorkspace.name = "Personal"
        personalWorkspace.order = 0

        let workWorkspace = Workspace(context: viewContext)
        workWorkspace.id = UUID()
        workWorkspace.name = "Work"
        workWorkspace.order = 1

        // Create sample repository
        let sampleRepo = Repository(context: viewContext)
        sampleRepo.id = UUID()
        sampleRepo.name = "sample-project"
        sampleRepo.path = "/Users/sample/projects/sample-project"
        sampleRepo.workspace = personalWorkspace
        sampleRepo.lastUpdated = Date()

        // Create sample worktrees
        let mainWorktree = Worktree(context: viewContext)
        mainWorktree.id = UUID()
        mainWorktree.path = "/Users/sample/projects/sample-project"
        mainWorktree.branch = "main"
        mainWorktree.isPrimary = true
        mainWorktree.repository = sampleRepo

        let featureWorktree = Worktree(context: viewContext)
        featureWorktree.id = UUID()
        featureWorktree.path = "/Users/sample/projects/sample-project-feature"
        featureWorktree.branch = "feature/new-ui"
        featureWorktree.isPrimary = false
        featureWorktree.repository = sampleRepo

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "aiX")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // 迁移旧的aizen数据到新的aiX位置
            migrateOldDataIfNeeded()
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Create default workspace if none exists
        if !inMemory {
            createDefaultWorkspaceIfNeeded()
        }
    }

    private func createDefaultWorkspaceIfNeeded() {
        let fetchRequest: NSFetchRequest<Workspace> = Workspace.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let count = try container.viewContext.count(for: fetchRequest)
            if count == 0 {
                let defaultWorkspace = Workspace(context: container.viewContext)
                defaultWorkspace.id = UUID()
                defaultWorkspace.name = "Personal"
                defaultWorkspace.order = 0

                try container.viewContext.save()
            }
        } catch {
            logger.error("Failed to create default workspace: \(error)")
        }
    }
    
    private func migrateOldDataIfNeeded() {
        let fileManager = FileManager.default
        
        // 获取应用支持目录
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        // 旧的aizen数据路径
        let oldAppDir = appSupport.appendingPathComponent("aizen", isDirectory: true)
        let oldStoreURL = oldAppDir.appendingPathComponent("aizen.sqlite")
        let oldStoreWAL = oldAppDir.appendingPathComponent("aizen.sqlite-wal")
        let oldStoreSHM = oldAppDir.appendingPathComponent("aizen.sqlite-shm")
        
        // 新的aiX数据路径
        let newAppDir = appSupport.appendingPathComponent("aiX", isDirectory: true)
        let newStoreURL = newAppDir.appendingPathComponent("aiX.sqlite")
        
        // 检查旧数据是否存在，且新数据不存在
        guard fileManager.fileExists(atPath: oldStoreURL.path),
              !fileManager.fileExists(atPath: newStoreURL.path) else {
            return
        }
        
        logger.info("发现旧的aizen数据，开始迁移...")
        
        do {
            // 创建新目录
            try fileManager.createDirectory(at: newAppDir, withIntermediateDirectories: true)
            
            // 复制数据库文件
            try fileManager.copyItem(at: oldStoreURL, to: newStoreURL)
            logger.info("已复制数据库文件")
            
            // 复制WAL文件（如果存在）
            if fileManager.fileExists(atPath: oldStoreWAL.path) {
                let newWAL = newAppDir.appendingPathComponent("aiX.sqlite-wal")
                try fileManager.copyItem(at: oldStoreWAL, to: newWAL)
                logger.info("已复制WAL文件")
            }
            
            // 复制SHM文件（如果存在）
            if fileManager.fileExists(atPath: oldStoreSHM.path) {
                let newSHM = newAppDir.appendingPathComponent("aiX.sqlite-shm")
                try fileManager.copyItem(at: oldStoreSHM, to: newSHM)
                logger.info("已复制SHM文件")
            }
            
            logger.info("数据迁移完成！")
        } catch {
            logger.error("数据迁移失败: \(error)")
        }
    }
}
