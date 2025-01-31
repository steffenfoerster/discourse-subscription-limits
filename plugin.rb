# name: discourse-subscription-limits
# about: Limits posts and image uploads in the Image Critique category based on subscription tier.
# version: 1.0
# authors: Your Name
# url: https://your-website.com

enabled_site_setting :subscription_limits_enabled

# name: discourse-subscription-limits
# about: Limits posts and image uploads in the Image Critique category based on subscription tier.
# version: 1.0
# authors: Your Name
# url: https://your-website.com

enabled_site_setting :subscription_limits_enabled

# Register site settings so admins can change limits in the UI
register_integer_setting :basic_max_posts, default: 1, min: 0
register_integer_setting :premium_max_posts, default: 3, min: 0
register_integer_setting :elite_max_posts, default: 9999, min: 0

register_integer_setting :basic_max_images, default: 3, min: 0
register_integer_setting :premium_max_images, default: 5, min: 0
register_integer_setting :elite_max_images, default: 9999, min: 0

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

after_initialize do
  module ::SubscriptionLimits
    class UploadValidator
      def self.max_uploads(user)
        case user.primary_group_name
        when "Basic" then SiteSetting.basic_max_images
        when "Premium" then SiteSetting.premium_max_images
        else SiteSetting.elite_max_images # Default for Elite
        end
      end
    end
  end

  DiscourseEvent.on(:upload_created) do |upload, post|
    max_images = SubscriptionLimits::UploadValidator.max_uploads(upload.user)
    if post.uploads.count > max_images
      raise Discourse::InvalidAccess, "You've reached your image upload limit for this post."
    end
  end
end

after_initialize do
  module ::SubscriptionLimits
    class ResetLimitsJob < ::Jobs::Scheduled
      every 1.month

      def execute(args)
        DB.exec("UPDATE users SET monthly_posts_count = 0")
      end
    end
  end
end

