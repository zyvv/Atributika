//
//  Created by Pavel Sharanda on 02.03.17.
//  Copyright © 2017 Pavel Sharanda. All rights reserved.
//

import UIKit
import Atributika
import SafariServices

#if swift(>=4.2)
public typealias TableViewCellStyle = UITableViewCell.CellStyle
#else
public typealias TableViewCellStyle = UITableViewCellStyle
#endif

class AttributedLabelDemoViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: CGRect(), style: .plain)
        
        tableView.delegate = self
        tableView.dataSource = self
        #if swift(>=4.2)
        tableView.rowHeight = UITableView.automaticDimension
        #else
        tableView.rowHeight = UITableViewAutomaticDimension
        #endif        
        tableView.estimatedRowHeight = 50
        return tableView
    }()
    
    private var tweets: [String] = [
        """
        垃圾单位 转@<a href="https://fanfou.com/李总好" class="former">李总好</a> 什么单位？转@<a href="https://fanfou.com/whatastupidgirl" class="former">小满.</a> 公司上周终于艰难地把去年的社保交上，然后这个月的社保又交不上了；现在马上要2月了，12月的工资还没发。有比我更惨的吗？
        """,
        """
        #<a href="/q/%E5%9C%B0%E6%96%B9+%EF%BC%8C%40%E4%BA%A6%E6%99%BA%E5%A2%A8%E8%AF%AD+%2C">地方 ，@亦智墨语 ,</a>#谁来看书#<a href="/q/%EF%BC%8C">，</a>#我来看 。 。。。法司法局拉手孔
        """,
        """
        来来来 @<a href="http://fanfou.com/~8kyx3zsk7JE" class="former">亦智墨语</a> #<a href="/q/%E5%93%88%E5%93%88%E5%93%88%E5%93%88">哈哈哈哈</a>#你好呀# 我是 你好<a href="https://www.douban.com/" title="https://www.douban.com/" rel="nofollow" target="_blank">https://www.douban.com/</a> 哈哈哈 再来一个@<a href="http://fanfou.com/~8kyx3zsk7JE" class="former">亦智墨语</a>
        """,
    ]
    
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "AttributedLabel"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        self.registerForPreviewing(with: self, sourceView: tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
}

extension AttributedLabelDemoViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        SFSafariViewController(url: URL(string: "http://www.baidu.com")!)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
//        SFSafariViewController(url: URL(string: "http://www.baidu.com")!)
    }
    
    
}

extension AttributedLabelDemoViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "CellId"
        let cell = (tableView.dequeueReusableCell(withIdentifier: cellId) as? TweetCell) ?? TweetCell(style: .default, reuseIdentifier: cellId)
        cell.tweet = tweets[indexPath.row]
        cell.onHighlight = {label, _ in
            
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class TweetCell: UITableViewCell {
    
    var onHighlight: ((AttributedLabel, Detection)->Void)?
    private let tweetLabel = AttributedLabel()

    override init(style: TableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        tweetLabel.onClick = { label, detection in
            switch detection.type {
            case .hashtag(let tag, let url):
                print("tap hashtag: \(tag)   \(url)")
            case .mention(let name, let url):
                print("tap mention: \(name)  \(url.absoluteString)")
                    UIApplication.shared.openURL(url)
            case .link(let url):
                UIApplication.shared.openURL(url)
            case .tag(let tag):
                if tag.name == "a", let href = tag.attributes["href"], let url = URL(string: href) {
                    UIApplication.shared.openURL(url)
                }
            default:
                break
            }
        }

        contentView.addSubview(tweetLabel)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        tweetLabel.translatesAutoresizingMaskIntoConstraints = false
        tweetLabel.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor).isActive = true
        tweetLabel.topAnchor.constraint(equalTo: marginGuide.topAnchor).isActive = true
        tweetLabel.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor).isActive = true
        tweetLabel.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor).isActive = true
        tweetLabel.numberOfLines = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var tweet: String? {
        didSet {
            let all = Style.font(.systemFont(ofSize: 20))
            let link = Style
                .foregroundColor(.blue, .normal)
                .foregroundColor(.brown, .highlighted)
                .backgroundColor(.orange, .highlighted)
            tweetLabel.attributedText = tweet?.style(hashtagStyle: link, mentionStyle: link, linkStyle: link)
                .styleAll(all)
        }
    }
}



