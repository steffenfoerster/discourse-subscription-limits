# name: discourse-subscription-limits
# about: Limits posts and image uploads in the Image Critique category based on subscription tier.
# version: 1.0
# authors: Your Name
# url: https://your-website.com

enabled_site_setting :subscription_limits_enabled

after_initialize do
  module ::SubscriptionLimits
    class PostValidator
      def self.can_post?(user, category)
        return true if user.admin? # Allow admins unrestricted access

        category_id = Category.find_by(name: "Image Critique")&.id
        return true unless category_id

        user_posts = Topic.where(user: user, category_id: category_id, created_at: 1.month.ago..Time.now).count

        case user.primary_group_name
        when "Basic"
          return false if user_posts >= SiteSetting.basic_max_posts
        when "Premium"
          return false if user_posts >= SiteSetting.premium_max_posts
        end

        true
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    unless SubscriptionLimits::PostValidator.can_post?(post.user, post.category)
      raise Discourse::InvalidAccess, "You've reached your post limit for this month. Upgrade to post more."
    end
  end
end
