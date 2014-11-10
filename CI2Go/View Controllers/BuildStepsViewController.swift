//
//  BuildStepsViewController.swift
//  CI2Go
//
//  Created by Atsushi Nagase on 11/10/14.
//  Copyright (c) 2014 LittleApps Inc. All rights reserved.
//

import UIKit

public class BuildStepsViewController: BaseTableViewController {
  public var isLoading = false
  public var build: Build? = nil {
    didSet(value) {
      if build?.number != nil && build?.project?.repositoryName != nil {
        title = "\(build!.project!.repositoryName!) #\(build!.number)"
        load()
      } else {
        title = ""
      }
    }
  }

  public override func awakeFromNib() {
    super.awakeFromNib()
    refreshControl = UIRefreshControl()
    refreshControl!.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
    tableView.addSubview(refreshControl!)
  }

  func refresh(sender :AnyObject?) {
    load()
  }

  public func load() {
    if isLoading {
      refreshControl?.endRefreshing()
      return
    }
    let m = CircleCIAPISessionManager()
    m.GET(build?.apiPath!, parameters: [],
      success: { (op: AFHTTPRequestOperation!, data: AnyObject!) -> Void in
        self.refreshControl?.endRefreshing()
        MagicalRecord.saveWithBlock({ (context: NSManagedObjectContext!) -> Void in
          Build.MR_importFromObject(data, inContext: context)
          return
          },
          completion: { (success: Bool, error: NSError!) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
              self.isLoading = false
              self.tableView.reloadData()
            })
            return
        })
      })
      { (op: AFHTTPRequestOperation!, err: NSError!) -> Void in
        self.isLoading = false
    }
  }

  public override func createFetchedResultsController(context: NSManagedObjectContext) -> NSFetchedResultsController {
    return BuildAction.MR_fetchAllGroupedBy("type", withPredicate: predicate(), sortedBy: "type,index,nodeIndex", ascending: false, delegate: self, inContext: context)
  }

  public override func predicate() -> NSPredicate? {
    return NSPredicate(format: "buildStep.build.buildID = %@", build!.buildID!)
  }

  override func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
    let action = fetchedResultsController.objectAtIndexPath(indexPath) as? BuildAction
    let actionCell = cell as? BuildActionTableViewCell
    actionCell?.buildAction = action
    let hasOutput = action?.outputURL != nil
    cell.accessoryType = hasOutput ? UITableViewCellAccessoryType.DisclosureIndicator : UITableViewCellAccessoryType.None
    cell.selectionStyle = hasOutput ? UITableViewCellSelectionStyle.Default : UITableViewCellSelectionStyle.None
  }

  public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
    if let action = sectionInfo.objects[0] as? BuildAction {
      return action.type?.componentsSeparatedByString(": ").last?.humanize
    }
    return nil
  }

  public override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
    if let cell = sender as? UITableViewCell {
      if let indexPath = tableView.indexPathForCell(cell) {
        if let action = fetchedResultsController.objectAtIndexPath(indexPath) as? BuildAction {
          return action.outputURL != nil
        }
      }
    }
    return false
  }

  public override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    let cell = sender as? BuildActionTableViewCell
    let nvc = segue.destinationViewController as? UINavigationController
    let vc = nvc?.topViewController as? BuildLogViewController
    vc?.buildAction = cell?.buildAction
    vc?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
    vc?.navigationItem.leftItemsSupplementBackButton = true
  }
  
}
